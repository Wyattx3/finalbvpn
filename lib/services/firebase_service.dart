import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:persistent_device_id/persistent_device_id.dart';

/// Firebase Service - Handles all backend communication using Firestore directly
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  String? _deviceId;
  String? _deviceModel;
  bool _isInitialized = false;

  // ========== DEVICE ID ==========
  static const String _deviceIdKey = 'suk_fhyoke_device_id';
  
  /// Force refresh device ID (reload from system)
  Future<void> refreshDeviceId() async {
    _deviceId = null;
    debugPrint('📱 Refreshing device ID...');
    await getDeviceId();
  }
  
  /// Get PERMANENT device ID that survives app uninstall
  /// Priority order:
  /// 1. SharedPreferences (most reliable - survives reinstall if backup enabled)
  /// 2. persistent_device_id package (uses secure storage)
  /// 3. Platform-specific fallback
  Future<String> getDeviceId() async {
    if (_deviceId != null) {
      return _deviceId!;
    }

    try {
      // Step 1: Try to get from SharedPreferences first (most reliable)
      final prefs = await SharedPreferences.getInstance();
      final savedDeviceId = prefs.getString(_deviceIdKey);
      
      if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
        _deviceId = savedDeviceId;
        debugPrint('📱 Device ID from SharedPreferences: $_deviceId');
        
        // Also get device model
        await _loadDeviceModel();
        return _deviceId!;
      }
      
      debugPrint('📱 No saved device ID, generating new one...');
      
      // Step 2: Generate new device ID
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        _deviceId = 'web${webInfo.userAgent?.hashCode.toRadixString(16) ?? DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
        _deviceModel = 'Web Browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        debugPrint('📱 Getting Android info...');
        debugPrint('📱 Brand: ${androidInfo.brand}, Model: ${androidInfo.model}');
        
        // Try persistent_device_id first
        String? persistentId;
        try {
          // Call as a function - returns Future<String?>
          persistentId = await PersistentDeviceId.getDeviceId();
          debugPrint('📱 PersistentDeviceId returned: $persistentId');
        } catch (e) {
          debugPrint('⚠️ PersistentDeviceId error: $e');
        }
        
        if (persistentId != null && persistentId.isNotEmpty) {
          // Check if this looks like a Base64 string (old format)
          // Base64 strings often contain +, /, = characters
          if (persistentId.contains('/') || persistentId.contains('+') || persistentId.contains('=')) {
            // Convert Base64 ID to a cleaner hex format for readability
            final hashCode = persistentId.hashCode;
            final cleanId = hashCode.toRadixString(16).padLeft(12, '0');
            _deviceId = cleanId;
            debugPrint('📱 Converted Base64 to clean ID: $_deviceId');
          } else {
            // Already a clean format, use as-is
            _deviceId = persistentId;
          }
        } else {
          // Fallback: Create a stable ID from hardware info
          // This combination should be unique per device
          final fingerprint = androidInfo.fingerprint;
          final serialNumber = androidInfo.serialNumber;
          final androidId = androidInfo.id;
          
          // Create hash from multiple sources for stability
          final combined = '$fingerprint|$serialNumber|$androidId';
          final hash = combined.hashCode.toRadixString(16).padLeft(16, '0');
          _deviceId = 'android_$hash';
          debugPrint('📱 Generated fallback ID from hardware: $_deviceId');
        }
        
        _deviceModel = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'ios${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
        _deviceModel = '${iosInfo.name} ${iosInfo.model}';
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        _deviceId = windowsInfo.deviceId.isNotEmpty 
            ? windowsInfo.deviceId 
            : 'win${windowsInfo.computerName.hashCode.toRadixString(16)}';
        _deviceModel = windowsInfo.productName;
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        _deviceId = macInfo.systemGUID ?? 'mac${macInfo.computerName.hashCode.toRadixString(16)}';
        _deviceModel = macInfo.model;
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        _deviceId = linuxInfo.machineId ?? 'lnx${linuxInfo.id.hashCode.toRadixString(16)}';
        _deviceModel = linuxInfo.prettyName;
      } else {
        _deviceId = 'dev${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
        _deviceModel = 'Unknown Device';
      }
      
      // Step 3: Save to SharedPreferences for future use
      await prefs.setString(_deviceIdKey, _deviceId!);
      debugPrint('📱 Device ID saved to SharedPreferences: $_deviceId');
      debugPrint('📱 Device Model: $_deviceModel');
      
    } catch (e) {
      debugPrint('❌ Error getting device info: $e');
      _deviceId = 'err${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
      _deviceModel = 'Unknown Device';
    }

    return _deviceId!;
  }
  
  /// Load device model info
  Future<void> _loadDeviceModel() async {
    if (_deviceModel != null) return;
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceModel = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceModel = '${iosInfo.name} ${iosInfo.model}';
      } else {
        _deviceModel = 'Unknown Device';
      }
    } catch (e) {
      _deviceModel = 'Unknown Device';
    }
  }

  String get deviceModel => _deviceModel ?? 'Unknown Device';

  String _getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  // ========== IP/GEOLOCATION (OPTIONAL) ==========

  /// Get IP address and country info from free API
  /// This is OPTIONAL - app works without it
  /// Uses very short timeout (2s) to avoid blocking
  Future<Map<String, String>> _getIpInfo() async {
    // Single fast API with very short timeout
    // If blocked, we skip immediately - IP info is not critical
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      
      // Try ipapi.co first (usually accessible)
      final request = await client.getUrl(Uri.parse('https://ipapi.co/json/')).timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('timeout'),
      );
      
      final response = await request.close().timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('timeout'),
      );

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = json.decode(responseBody) as Map<String, dynamic>;
        
        return {
          'ipAddress': data['ip']?.toString() ?? '',
          'country': data['country_name']?.toString() ?? 'Unknown',
          'countryCode': data['country_code']?.toString() ?? '',
          'city': data['city']?.toString() ?? '',
        };
      }
    } catch (e) {
      // Silently fail - IP info is optional
      debugPrint('📍 IP check skipped: $e');
    }
    
    return {'ipAddress': '', 'country': 'Unknown', 'countryCode': '', 'city': ''};
  }
  
  /// Get country flag emoji from country code
  String _getCountryFlag(String countryCode) {
    if (countryCode.isEmpty || countryCode.length != 2) return '🌍';
    
    final codeUnits = countryCode.toUpperCase().codeUnits;
    final flag = String.fromCharCode(codeUnits[0] + 127397) +
                 String.fromCharCode(codeUnits[1] + 127397);
    return flag;
  }

  // ========== INITIALIZATION ==========
  
  /// Initialize Firebase and register device
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final deviceId = await getDeviceId();
      debugPrint('🔥 Firebase initializing for device: $deviceId');

      // IP check is OPTIONAL - skip entirely in restricted networks
      // This info is only for admin analytics, not required for VPN to work
      Map<String, String> ipInfo = {'ipAddress': '', 'country': 'Unknown', 'countryCode': '', 'city': ''};
      String flag = '🌍';
      
      // Try to get IP info in background (non-blocking, 3 second max)
      // If it fails, we just continue without it
      try {
        final ipFuture = _getIpInfo();
        ipInfo = await ipFuture.timeout(
          const Duration(seconds: 3),
          onTimeout: () => {'ipAddress': '', 'country': 'Unknown', 'countryCode': '', 'city': ''},
        );
        flag = _getCountryFlag(ipInfo['countryCode'] ?? '');
        debugPrint('📍 Got IP info: ${ipInfo['country']}');
      } catch (e) {
        debugPrint('📍 IP check skipped (network restricted) - this is OK');
        // Continue with default values - VPN will still work
      }
      
      // Check if device already exists (with timeout for restricted networks)
      DocumentSnapshot<Map<String, dynamic>>? deviceDoc;
      Map<String, dynamic>? existingData;
      bool isBanned = false;
      bool hasDataUsage = false;
      
      try {
        deviceDoc = await _firestore.collection('devices').doc(deviceId).get().timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            debugPrint('⏰ Firebase get device timeout');
            throw TimeoutException('Firebase timeout');
          },
        );
        existingData = deviceDoc.data();
        isBanned = existingData?['status'] == 'banned';
        hasDataUsage = existingData?['dataUsage'] != null;
      } catch (e) {
        debugPrint('⚠️ Could not check device in Firebase: $e');
        // Continue with default values - device will be registered as new
      }
      
      // Register/update device in Firestore directly
      debugPrint('🔥 Registering device to Firebase:');
      debugPrint('   - deviceId: $deviceId');
      debugPrint('   - deviceModel: $deviceModel');
      debugPrint('   - platform: ${_getPlatform()}');
      debugPrint('   - isBanned: $isBanned');
      debugPrint('   - hasDataUsage: $hasDataUsage');
      
      // Prepare update data - preserve banned status and data usage
      final updateData = <String, dynamic>{
        'deviceId': deviceId,
        'deviceModel': deviceModel,
        'platform': _getPlatform(),
        'appVersion': '1.0.0',
        'ipAddress': ipInfo['ipAddress'],
        'country': ipInfo['country'],
        'countryCode': ipInfo['countryCode'],
        'city': ipInfo['city'],
        'flag': flag,
        'lastSeen': FieldValue.serverTimestamp(),
      };
      
      // Only set status to 'online' if device is not banned
      if (!isBanned) {
        updateData['status'] = 'online';
        debugPrint('   - Setting status to online (not banned)');
      } else {
        debugPrint('   - Preserving banned status');
      }
      
      // Only set dataUsage to 0 if device doesn't exist or doesn't have dataUsage
      if (!hasDataUsage) {
        updateData['dataUsage'] = 0;
        debugPrint('   - Setting dataUsage to 0 (new device)');
      } else {
        debugPrint('   - Preserving existing dataUsage: ${existingData?['dataUsage']}');
      }
      
      // Only set createdAt if device is new
      if (deviceDoc == null || !deviceDoc.exists) {
        updateData['createdAt'] = FieldValue.serverTimestamp();
      }
      
      // Save to Firebase with timeout
      try {
        await _firestore.collection('devices').doc(deviceId).set(updateData, SetOptions(merge: true)).timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            debugPrint('⏰ Firebase set device timeout');
            throw TimeoutException('Firebase set timeout');
          },
        );
        
        // 📝 Log login activity to Firebase (non-blocking)
        _logLoginActivity(deviceId, ipInfo, flag).catchError((e) {
          debugPrint('⚠️ Failed to log login activity: $e');
        });
        
        _isInitialized = true;
        debugPrint('✅ Firebase initialized successfully!');
        debugPrint('📍 IP: ${ipInfo['ipAddress']}, Country: ${ipInfo['country']}');
        return true;
      } catch (e) {
        debugPrint('⚠️ Firebase save failed: $e - continuing in offline mode');
        // Still mark as initialized to allow app to work offline
        _isInitialized = true;
        return false;
      }
    } catch (e) {
      debugPrint('❌ Firebase initialization error: $e');
      return false;
    }
  }

  // ========== LOGIN ACTIVITY ==========
  
  /// Log login activity to Firebase
  Future<void> _logLoginActivity(String deviceId, Map<String, String> ipInfo, String flag) async {
    try {
      await _firestore.collection('login_activity').add({
        'deviceId': deviceId,
        'deviceModel': deviceModel,
        'platform': _getPlatform(),
        'ipAddress': ipInfo['ipAddress'] ?? '',
        'country': ipInfo['country'] ?? 'Unknown',
        'countryCode': ipInfo['countryCode'] ?? '',
        'city': ipInfo['city'] ?? '',
        'flag': flag,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'app_open',
      });
      debugPrint('📝 Login activity logged');
    } catch (e) {
      debugPrint('⚠️ Failed to log login activity: $e');
    }
  }

  // ========== DEVICE FUNCTIONS ==========
  
  /// Register device with Firebase (using Firestore directly)
  Future<Map<String, dynamic>> registerDevice() async {
    final deviceId = await getDeviceId();

    try {
      // Get IP and geolocation info with timeout
      Map<String, String> ipInfo;
      try {
        ipInfo = await _getIpInfo().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ IP check timeout in registerDevice');
            return {'ipAddress': '', 'country': 'Unknown', 'countryCode': '', 'city': ''};
          },
        );
      } catch (e) {
        debugPrint('⚠️ IP check error in registerDevice: $e');
        ipInfo = {'ipAddress': '', 'country': 'Unknown', 'countryCode': '', 'city': ''};
      }
      final flag = _getCountryFlag(ipInfo['countryCode'] ?? '');
      
      // Check if device already exists
      final deviceDoc = await _firestore.collection('devices').doc(deviceId).get();
      final existingData = deviceDoc.data();
      final isBanned = existingData?['status'] == 'banned';
      final hasDataUsage = existingData?['dataUsage'] != null;
      final hasBalance = existingData?['balance'] != null;
      
      // Prepare update data - preserve banned status, data usage, and balance
      final updateData = <String, dynamic>{
        'deviceId': deviceId,
        'deviceModel': deviceModel,
        'platform': _getPlatform(),
        'appVersion': '1.0.0',
        'ipAddress': ipInfo['ipAddress'],
        'country': ipInfo['country'],
        'countryCode': ipInfo['countryCode'],
        'city': ipInfo['city'],
        'flag': flag,
        'lastSeen': FieldValue.serverTimestamp(),
      };
      
      // Only set status to 'online' if device is not banned
      if (!isBanned) {
        updateData['status'] = 'online';
        debugPrint('   - Setting status to online (not banned)');
      } else {
        debugPrint('   - Preserving banned status');
      }
      
      // Only set balance to 0 if device doesn't exist or doesn't have balance
      if (!hasBalance) {
        updateData['balance'] = 0;
      }
      
      // Only set dataUsage to 0 if device doesn't exist or doesn't have dataUsage
      if (!hasDataUsage) {
        updateData['dataUsage'] = 0;
      }
      
      // Only set createdAt if device is new
      if (!deviceDoc.exists) {
        updateData['createdAt'] = FieldValue.serverTimestamp();
      }
      
      await _firestore.collection('devices').doc(deviceId).set(updateData, SetOptions(merge: true));
      
      debugPrint('✅ Device registered: $deviceId');
      debugPrint('📍 IP: ${ipInfo['ipAddress']}, Country: ${ipInfo['country']}');
      return {'success': true, 'deviceId': deviceId};
    } catch (e) {
      debugPrint('❌ Error registering device: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update device status (online/offline)
  Future<void> updateDeviceStatus(String status) async {
    final deviceId = await getDeviceId();
    
    try {
      // Don't overwrite 'banned' status with 'online' or 'offline'
      if (status != 'banned') {
        final doc = await _firestore.collection('devices').doc(deviceId).get();
        if (doc.exists && doc.data()?['status'] == 'banned') {
          debugPrint('🚫 Device is banned - not updating status to $status');
          return;
        }
      }
      
      await _firestore.collection('devices').doc(deviceId).update({
        'status': status,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      debugPrint('📍 Device status updated: $status');
    } catch (e) {
      debugPrint('❌ Error updating device status: $e');
    }
  }
  
  /// Send heartbeat to keep device online (update lastSeen)
  Future<void> sendHeartbeat() async {
    final deviceId = await getDeviceId();
    
    try {
      await _firestore.collection('devices').doc(deviceId).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
      debugPrint('💓 Heartbeat sent');
    } catch (e) {
      debugPrint('❌ Error sending heartbeat: $e');
    }
  }

  /// Listen to device ban status in real-time
  /// Returns a stream that emits true when device is banned, false otherwise
  Stream<bool> listenToBanStatus() async* {
    final deviceId = await getDeviceId();
    
    yield* _firestore
        .collection('devices')
        .doc(deviceId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return false;
          final status = doc.data()?['status'] as String?;
          final isBanned = status == 'banned';
          if (isBanned) {
            debugPrint('🚫 DEVICE BANNED! Status: $status');
          }
          return isBanned;
        });
  }

  /// Get ban screen SDUI config from Firebase
  Future<Map<String, dynamic>> getBanScreenConfig() async {
    try {
      final doc = await _firestore.collection('sdui_configs').doc('banned_screen').get();
      
      if (doc.exists && doc.data() != null) {
        debugPrint('✅ Ban screen SDUI config loaded');
        return doc.data()!['config'] ?? {};
      }
      
      debugPrint('⚠️ Ban screen SDUI config not found, using defaults');
      return {};
    } catch (e) {
      debugPrint('❌ Error getting ban screen config: $e');
      return {};
    }
  }

  // ========== BALANCE & REWARDS ==========
  
  /// Get current balance from Firestore
  Future<int> getBalance() async {
    final deviceId = await getDeviceId();
    
    try {
      final doc = await _firestore.collection('devices').doc(deviceId).get();
      if (doc.exists) {
        return (doc.data()?['balance'] as int?) ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Error getting balance: $e');
      return 0;
    }
  }

  /// Stream balance updates
  Stream<int> getBalanceStream() {
    return _firestore
        .collection('devices')
        .doc(_deviceId)
        .snapshots()
        .map((doc) => (doc.data()?['balance'] as int?) ?? 0);
  }

  /// Listen to real-time balance updates
  Stream<int> listenToBalance() async* {
    final deviceId = await getDeviceId();
    yield* _firestore
        .collection('devices')
        .doc(deviceId)
        .snapshots()
        .map((doc) => (doc.data()?['balance'] as int?) ?? 0);
  }

  /// Add reward for watching ad - ALL validation done server-side
  /// [rewardAmount] - Custom reward amount (from SDUI), if null uses SDUI config
  /// [addVpnTime] - Whether to add VPN time bonus (only for VPN page ads)
  Future<Map<String, dynamic>> addAdReward({int? rewardAmount, bool addVpnTime = false}) async {
    final deviceId = await getDeviceId();
    
    try {
      // Get reward config from SDUI (earn_money screen config)
      final sduiDoc = await _firestore.collection('sdui_configs').doc('earn_money').get();
      final sduiConfig = sduiDoc.data()?['config'] as Map<String, dynamic>? ?? {};
      
      // Use SDUI config values with fallbacks
      // Cast all values to int (Firestore may return num/double)
      final rewardPerAd = rewardAmount ?? (sduiConfig['reward_per_ad'] as num?)?.toInt() ?? 30;
      final timeBonusSeconds = addVpnTime ? ((sduiConfig['time_bonus_seconds'] as num?)?.toInt() ?? 7200) : 0;
      final maxAdsPerDay = (sduiConfig['max_ads_per_day'] as num?)?.toInt() ?? 100;
      final cooldownAdsCount = (sduiConfig['cooldown_ads_count'] as num?)?.toInt() ?? 10;
      final cooldownMinutes = (sduiConfig['cooldown_minutes'] as num?)?.toInt() ?? 10;
      
      debugPrint('💰 Ad reward config (from SDUI) - rewardPerAd: $rewardPerAd, timeBonusSeconds: $timeBonusSeconds, addVpnTime: $addVpnTime');

      // Get current device data
      final deviceDoc = await _firestore.collection('devices').doc(deviceId).get();
      final deviceData = deviceDoc.data() ?? {};
      
      // Check if we need to reset daily stats
      final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
      final lastResetDate = deviceData['lastResetDate'] as String? ?? '';
      
      int currentTodayEarnings = (deviceData['todayEarnings'] as int?) ?? 0;
      int currentAdsWatchedToday = (deviceData['adsWatchedToday'] as int?) ?? 0;
      int adWatchCount = (deviceData['adWatchCount'] as int?) ?? 0;
      
      // Reset if new day
      if (lastResetDate != today) {
        currentTodayEarnings = 0;
        currentAdsWatchedToday = 0;
        adWatchCount = 0;
        debugPrint('📅 New day - resetting daily stats');
      }
      
      // Check daily limit (SERVER-SIDE VALIDATION)
      if (currentAdsWatchedToday >= maxAdsPerDay) {
        debugPrint('❌ Daily limit reached');
        return {'success': false, 'error': 'daily_limit', 'message': 'Daily limit reached'};
      }
      
      // Check cooldown (SERVER-SIDE VALIDATION)
      final cooldownEndTime = deviceData['cooldownEndTime'] as Timestamp?;
      if (cooldownEndTime != null) {
        final cooldownEnd = cooldownEndTime.toDate();
        if (DateTime.now().isBefore(cooldownEnd)) {
          final remaining = cooldownEnd.difference(DateTime.now()).inSeconds;
          debugPrint('❌ Cooldown active: $remaining seconds remaining');
          return {
            'success': false, 
            'error': 'cooldown', 
            'message': 'Please wait',
            'cooldownRemaining': remaining,
          };
        }
      }

      // Calculate new cooldown
      final newAdWatchCount = adWatchCount + 1;
      Timestamp? newCooldownEndTime;
      int resetAdWatchCount = newAdWatchCount;
      
      if (newAdWatchCount >= cooldownAdsCount) {
        // Set cooldown
        newCooldownEndTime = Timestamp.fromDate(
          DateTime.now().add(Duration(minutes: cooldownMinutes))
        );
        resetAdWatchCount = 0;
        debugPrint('⏰ Cooldown started: $cooldownMinutes minutes');
      }

      // Get current VPN time remaining
      int currentVpnSeconds = (deviceData['vpnRemainingSeconds'] as num?)?.toInt() ?? 0;
      
      // Update balance and all stats in Firebase
      final updateData = {
        'balance': FieldValue.increment(rewardPerAd),
        'todayEarnings': currentTodayEarnings + rewardPerAd,
        'adsWatchedToday': currentAdsWatchedToday + 1,
        'adWatchCount': resetAdWatchCount,
        'lastResetDate': today,
        'lastAdWatchTime': FieldValue.serverTimestamp(),
        'vpnRemainingSeconds': currentVpnSeconds + timeBonusSeconds, // Add VPN time to Firebase
      };
      
      if (newCooldownEndTime != null) {
        updateData['cooldownEndTime'] = newCooldownEndTime;
      }
      
      await _firestore.collection('devices').doc(deviceId).update(updateData);

      // Log activity
      await _firestore.collection('activity_logs').add({
        'deviceId': deviceId,
        'type': 'ad_reward',
        'description': 'Watched reward ad',
        'amount': rewardPerAd,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final newVpnSeconds = currentVpnSeconds + timeBonusSeconds;
      debugPrint('✅ Ad reward added: $rewardPerAd points, VPN time: $newVpnSeconds seconds (ads today: ${currentAdsWatchedToday + 1})');
      return {
        'success': true,
        'pointsEarned': rewardPerAd,
        'timeBonusSeconds': timeBonusSeconds,
        'vpnRemainingSeconds': newVpnSeconds, // Total VPN seconds from Firebase
        'todayEarnings': currentTodayEarnings + rewardPerAd,
        'adsWatchedToday': currentAdsWatchedToday + 1,
        'cooldownStarted': newCooldownEndTime != null,
        'cooldownDuration': cooldownMinutes * 60, // Cooldown duration in seconds (from SDUI)
      };
    } catch (e) {
      debugPrint('❌ Error adding ad reward: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Check if user can watch ad (SERVER-SIDE check)
  Future<Map<String, dynamic>> canWatchAd() async {
    final deviceId = await getDeviceId();
    
    try {
      // Get config from SDUI (earn_money screen config)
      final sduiDoc = await _firestore.collection('sdui_configs').doc('earn_money').get();
      final sduiConfig = sduiDoc.data()?['config'] as Map<String, dynamic>? ?? {};
      final maxAdsPerDay = (sduiConfig['max_ads_per_day'] as int?) ?? 100;
      
      final deviceDoc = await _firestore.collection('devices').doc(deviceId).get();
      final deviceData = deviceDoc.data() ?? {};
      
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final lastResetDate = deviceData['lastResetDate'] as String? ?? '';
      
      int adsWatchedToday = (deviceData['adsWatchedToday'] as int?) ?? 0;
      if (lastResetDate != today) {
        adsWatchedToday = 0;
      }
      
      // Check daily limit
      if (adsWatchedToday >= maxAdsPerDay) {
        return {'canWatch': false, 'reason': 'daily_limit'};
      }
      
      // Check cooldown
      final cooldownEndTime = deviceData['cooldownEndTime'] as Timestamp?;
      if (cooldownEndTime != null) {
        final cooldownEnd = cooldownEndTime.toDate();
        if (DateTime.now().isBefore(cooldownEnd)) {
          final remaining = cooldownEnd.difference(DateTime.now()).inSeconds;
          return {
            'canWatch': false, 
            'reason': 'cooldown',
            'cooldownRemaining': remaining,
          };
        }
      }
      
      return {'canWatch': true};
    } catch (e) {
      debugPrint('❌ Error checking canWatchAd: $e');
      return {'canWatch': false, 'reason': 'error'};
    }
  }
  
  /// Get daily stats from Firebase
  Future<Map<String, dynamic>> getDailyStats() async {
    final deviceId = await getDeviceId();
    
    try {
      final deviceDoc = await _firestore.collection('devices').doc(deviceId).get();
      final deviceData = deviceDoc.data() ?? {};
      
      // Check if we need to reset daily stats
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final lastResetDate = deviceData['lastResetDate'] as String? ?? '';
      
      if (lastResetDate != today) {
        // New day - return zeros
        return {
          'todayEarnings': 0,
          'adsWatchedToday': 0,
        };
      }
      
      return {
        'todayEarnings': (deviceData['todayEarnings'] as int?) ?? 0,
        'adsWatchedToday': (deviceData['adsWatchedToday'] as int?) ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Error getting daily stats: $e');
      return {'todayEarnings': 0, 'adsWatchedToday': 0};
    }
  }
  
  /// Listen to daily stats changes
  Stream<Map<String, dynamic>> listenToDailyStats() async* {
    final deviceId = await getDeviceId();
    
    yield* _firestore
        .collection('devices')
        .doc(deviceId)
        .snapshots()
        .map((doc) {
          final data = doc.data() ?? {};
          final today = DateTime.now().toIso8601String().substring(0, 10);
          final lastResetDate = data['lastResetDate'] as String? ?? '';
          
          if (lastResetDate != today) {
            return {'todayEarnings': 0, 'adsWatchedToday': 0};
          }
          
          return {
            'todayEarnings': (data['todayEarnings'] as int?) ?? 0,
            'adsWatchedToday': (data['adsWatchedToday'] as int?) ?? 0,
          };
        });
  }

  // ========== VPN TIME MANAGEMENT ==========
  
  /// Get VPN remaining time from Firebase
  Future<int> getVpnRemainingSeconds() async {
    final deviceId = await getDeviceId();
    
    try {
      final doc = await _firestore.collection('devices').doc(deviceId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data == null) return 0;
        final vpnSeconds = data['vpnRemainingSeconds'];
        if (vpnSeconds == null) return 0;
        if (vpnSeconds is int) return vpnSeconds;
        if (vpnSeconds is num) return vpnSeconds.toInt();
        return 0;
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Error getting VPN time: $e');
      return 0;
    }
  }

  /// Listen to VPN remaining time changes
  Stream<int> listenToVpnTime() async* {
    final deviceId = await getDeviceId();
    
    yield* _firestore
        .collection('devices')
        .doc(deviceId)
        .snapshots()
        .map((doc) {
          try {
            final data = doc.data();
            if (data == null) return 0;
            final vpnSeconds = data['vpnRemainingSeconds'];
            if (vpnSeconds == null) return 0;
            if (vpnSeconds is int) return vpnSeconds;
            if (vpnSeconds is num) return vpnSeconds.toInt();
            return 0;
          } catch (e) {
            debugPrint('❌ Error parsing vpnRemainingSeconds: $e');
            return 0;
          }
        });
  }

  /// Update VPN remaining time in Firebase (called periodically while connected)
  Future<void> updateVpnTime(int seconds) async {
    final deviceId = await getDeviceId();
    
    try {
      await _firestore.collection('devices').doc(deviceId).update({
        'vpnRemainingSeconds': seconds,
        'lastVpnUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating VPN time: $e');
    }
  }

  /// Decrement VPN time by 1 second (used during active VPN connection)
  Future<void> decrementVpnTime() async {
    final deviceId = await getDeviceId();
    
    try {
      // Use transaction to ensure atomic decrement
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('devices').doc(deviceId);
        final doc = await transaction.get(docRef);
        
        if (doc.exists) {
          final currentSeconds = (doc.data()?['vpnRemainingSeconds'] as num?)?.toInt() ?? 0;
          if (currentSeconds > 0) {
            transaction.update(docRef, {
              'vpnRemainingSeconds': currentSeconds - 1,
            });
          }
        }
      });
    } catch (e) {
      // Silently fail - will sync on next update
    }
  }

  /// Sync VPN time to Firebase (batch update to reduce writes)
  Future<void> syncVpnTime(int seconds) async {
    final deviceId = await getDeviceId();
    
    try {
      await _firestore.collection('devices').doc(deviceId).update({
        'vpnRemainingSeconds': seconds,
      });
      debugPrint('⏱️ VPN time synced: $seconds seconds');
    } catch (e) {
      debugPrint('❌ Error syncing VPN time: $e');
    }
  }

  // ========== SERVER-SIDE VPN CONNECTION TRACKING ==========
  
  /// Start VPN connection session on server
  /// Records the start time so server can calculate elapsed time even if app crashes
  Future<void> startVpnSession() async {
    final deviceId = await getDeviceId();
    
    try {
      await _firestore.collection('devices').doc(deviceId).update({
        'vpnSessionActive': true,
        'vpnSessionStartTime': FieldValue.serverTimestamp(),
        'vpnLastHeartbeat': FieldValue.serverTimestamp(),
      });
      debugPrint('🟢 VPN session started on server');
    } catch (e) {
      debugPrint('❌ Error starting VPN session: $e');
    }
  }
  
  /// Stop VPN connection session on server
  /// Calculates elapsed time and deducts from remaining seconds
  Future<void> stopVpnSession() async {
    final deviceId = await getDeviceId();
    
    try {
      // Use transaction to ensure atomic time deduction
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('devices').doc(deviceId);
        final doc = await transaction.get(docRef);
        
        if (doc.exists) {
          final data = doc.data();
          if (data == null) return;
          
          final bool wasActive = data['vpnSessionActive'] == true;
          
          if (wasActive) {
            final startTime = data['vpnSessionStartTime'] as Timestamp?;
            final currentSeconds = (data['vpnRemainingSeconds'] as num?)?.toInt() ?? 0;
            
            if (startTime != null) {
              // Calculate elapsed time since session started
              final elapsed = DateTime.now().difference(startTime.toDate()).inSeconds;
              final newSeconds = (currentSeconds - elapsed).clamp(0, currentSeconds);
              
              transaction.update(docRef, {
                'vpnSessionActive': false,
                'vpnRemainingSeconds': newSeconds,
                'vpnSessionEndTime': FieldValue.serverTimestamp(),
                'vpnLastSessionDuration': elapsed,
              });
              
              debugPrint('🔴 VPN session stopped on server');
              debugPrint('   - Elapsed: $elapsed seconds');
              debugPrint('   - Remaining: $newSeconds seconds (was $currentSeconds)');
            } else {
              transaction.update(docRef, {
                'vpnSessionActive': false,
              });
            }
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Error stopping VPN session: $e');
    }
  }
  
  /// Send heartbeat for active VPN session
  /// Helps server detect stale sessions (app crashed without proper disconnect)
  Future<void> sendVpnHeartbeat() async {
    final deviceId = await getDeviceId();
    
    try {
      await _firestore.collection('devices').doc(deviceId).update({
        'vpnLastHeartbeat': FieldValue.serverTimestamp(),
      });
      debugPrint('💓 VPN heartbeat sent');
    } catch (e) {
      debugPrint('❌ Error sending VPN heartbeat: $e');
    }
  }
  
  /// Check for stale VPN session (app crashed while connected)
  /// If session was active but last heartbeat is too old, deduct the time
  /// Call this on app startup to handle cases where app was killed while VPN was connected
  Future<int> recoverStaleVpnSession() async {
    final deviceId = await getDeviceId();
    
    try {
      final result = await _firestore.runTransaction<int>((transaction) async {
        final docRef = _firestore.collection('devices').doc(deviceId);
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) return 0;
        
        final data = doc.data();
        if (data == null) return 0;
        
        final bool wasActive = data['vpnSessionActive'] == true;
        if (!wasActive) {
          // No stale session
          return (data['vpnRemainingSeconds'] as num?)?.toInt() ?? 0;
        }
        
        final startTime = data['vpnSessionStartTime'] as Timestamp?;
        final lastHeartbeat = data['vpnLastHeartbeat'] as Timestamp?;
        final currentSeconds = (data['vpnRemainingSeconds'] as num?)?.toInt() ?? 0;
        
        if (startTime == null) {
          // Invalid session state - just mark as inactive
          transaction.update(docRef, {'vpnSessionActive': false});
          return currentSeconds;
        }
        
        // Calculate time to deduct
        // Use the later of startTime or lastHeartbeat as the reference
        DateTime referenceTime = startTime.toDate();
        if (lastHeartbeat != null && lastHeartbeat.toDate().isAfter(referenceTime)) {
          referenceTime = lastHeartbeat.toDate();
        }
        
        final elapsed = DateTime.now().difference(referenceTime).inSeconds;
        
        // Only deduct if session was stale (no heartbeat for more than 60 seconds)
        // This prevents accidental deduction during normal reconnects
        final timeSinceHeartbeat = lastHeartbeat != null 
            ? DateTime.now().difference(lastHeartbeat.toDate()).inSeconds 
            : elapsed;
        
        if (timeSinceHeartbeat > 60) {
          // Session was stale - deduct elapsed time
          final newSeconds = (currentSeconds - elapsed).clamp(0, currentSeconds);
          
          transaction.update(docRef, {
            'vpnSessionActive': false,
            'vpnRemainingSeconds': newSeconds,
            'vpnStaleSessionRecovered': FieldValue.serverTimestamp(),
            'vpnStaleSessionDeducted': elapsed,
          });
          
          debugPrint('⚠️ Stale VPN session recovered!');
          debugPrint('   - Time since heartbeat: $timeSinceHeartbeat seconds');
          debugPrint('   - Deducted: $elapsed seconds');
          debugPrint('   - New remaining: $newSeconds seconds');
          
          return newSeconds;
        } else {
          // Session was active recently - likely a quick app restart
          // Just mark as inactive, don't deduct time
          transaction.update(docRef, {'vpnSessionActive': false});
          return currentSeconds;
        }
      });
      
      return result;
    } catch (e) {
      debugPrint('❌ Error recovering stale VPN session: $e');
      // On error, try to get current time
      return await getVpnRemainingSeconds();
    }
  }
  
  /// Check if there's an active VPN session on server
  Future<bool> isVpnSessionActive() async {
    final deviceId = await getDeviceId();
    
    try {
      final doc = await _firestore.collection('devices').doc(deviceId).get();
      if (doc.exists) {
        return doc.data()?['vpnSessionActive'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking VPN session: $e');
      return false;
    }
  }

  // ========== SERVERS ==========
  
  /// Get all servers from Firestore
  Future<List<Map<String, dynamic>>> getServers() async {
    try {
      // Add timeout to prevent hanging in restricted networks
      final snapshot = await _firestore
          .collection('servers')
          .where('status', isNotEqualTo: 'offline')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('⏰ getServers timeout - network may be restricted');
              throw TimeoutException('Firebase servers fetch timeout');
            },
          );

      debugPrint('✅ Loaded ${snapshot.docs.length} servers from Firebase');
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting servers: $e');
      return [];
    }
  }
  
  /// Check if a specific server is online (real-time check before connecting)
  Future<String> getServerStatus(String serverId) async {
    try {
      final doc = await _firestore.collection('servers').doc(serverId).get();
      if (doc.exists) {
        return doc.data()?['status'] as String? ?? 'offline';
      }
      return 'offline';
    } catch (e) {
      debugPrint('❌ Error checking server status: $e');
      return 'offline'; // Default to offline on error for safety
    }
  }

  /// Stream servers
  Stream<List<Map<String, dynamic>>> getServersStream() {
    return _firestore
        .collection('servers')
        .where('status', isNotEqualTo: 'offline')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
              'id': doc.id,
              ...doc.data(),
            }).toList());
  }

  // ========== SDUI CONFIG ==========
  
  /// Get screen configuration from Firestore
  Future<Map<String, dynamic>> getScreenConfig(String screenId) async {
    try {
      final doc = await _firestore.collection('sdui_configs').doc(screenId).get();
      
      if (doc.exists && doc.data() != null) {
        debugPrint('✅ SDUI config loaded: $screenId');
        return doc.data()!;
      }
      
      debugPrint('⚠️ SDUI config not found: $screenId');
      return {};
    } catch (e) {
      debugPrint('❌ Error getting screen config: $e');
      return {};
    }
  }

  // ========== APP SETTINGS ==========
  
  /// Get app settings
  Future<Map<String, dynamic>> getAppSettings() async {
    try {
      final doc = await _firestore.collection('app_settings').doc('global').get();
      
      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
      
      return _getDefaultSettings();
    } catch (e) {
      debugPrint('❌ Error getting app settings: $e');
      return _getDefaultSettings();
    }
  }

  Map<String, dynamic> _getDefaultSettings() {
    return {
      'rewardPerAd': 30,
      'maxAdsPerDay': 100,
      'timeBonusSeconds': 7200,
      'minWithdrawMMK': 20000,
      'paymentMethods': ['KBZ Pay', 'Wave Pay'],
    };
  }

  // ========== WITHDRAWALS ==========
  
  /// Submit withdrawal request
  Future<Map<String, dynamic>> submitWithdrawal({
    required int amount,
    required String method,
    required String accountNumber,
    required String accountName,
  }) async {
    final deviceId = await getDeviceId();
    
    try {
      // Check balance
      final currentBalance = await getBalance();
      if (currentBalance < amount) {
        return {'success': false, 'error': 'Insufficient balance'};
      }

      // Deduct balance
      await _firestore.collection('devices').doc(deviceId).update({
        'balance': FieldValue.increment(-amount),
      });

      // Create withdrawal request
      final withdrawalRef = await _firestore.collection('withdrawals').add({
        'deviceId': deviceId,
        'points': amount,
        'amount': amount, // 1 point = 1 MMK
        'method': method,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Log activity
      await _firestore.collection('activity_logs').add({
        'deviceId': deviceId,
        'type': 'withdrawal',
        'description': 'Withdrawal request ($method)',
        'amount': -amount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Withdrawal submitted: $amount points');
      return {'success': true, 'withdrawalId': withdrawalRef.id};
    } catch (e) {
      debugPrint('❌ Error submitting withdrawal: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get withdrawal history
  Future<List<Map<String, dynamic>>> getWithdrawalHistory() async {
    final deviceId = await getDeviceId();
    
    try {
      final snapshot = await _firestore
          .collection('withdrawals')
          .where('deviceId', isEqualTo: deviceId)
          .get();
      
      final docs = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
        'createdAt': (doc.data()['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
      }).toList();
      
      // Sort locally by createdAt descending
      docs.sort((a, b) {
        final aDate = a['createdAt'] as String?;
        final bDate = b['createdAt'] as String?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      
      return docs.take(50).toList();
    } catch (e) {
      debugPrint('❌ Error getting withdrawal history: $e');
      return [];
    }
  }

  /// Listen to withdrawal history in real-time
  Stream<List<Map<String, dynamic>>> listenToWithdrawals() {
    return Stream.fromFuture(getDeviceId()).asyncExpand((deviceId) {
      debugPrint('📜 Starting withdrawal listener for device: $deviceId');
      
      return _firestore
          .collection('withdrawals')
          .where('deviceId', isEqualTo: deviceId)
          .snapshots()
          .map((snapshot) {
            final docs = snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
                'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
                'processedAt': (data['processedAt'] as Timestamp?)?.toDate().toIso8601String(),
              };
            }).toList();
            
            // Sort locally by createdAt descending
            docs.sort((a, b) {
              final aDate = a['createdAt'] as String?;
              final bDate = b['createdAt'] as String?;
              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return bDate.compareTo(aDate);
            });
            
            return docs.take(50).toList();
          })
          .handleError((e) {
            debugPrint('❌ Withdrawal listener error: $e');
            return <Map<String, dynamic>>[];
          });
    });
  }

  // ========== ACTIVITY LOGS ==========
  
  /// Get activity logs
  Future<List<Map<String, dynamic>>> getActivityLogs({int limit = 50}) async {
    final deviceId = await getDeviceId();
    
    try {
      final snapshot = await _firestore
          .collection('activity_logs')
          .where('deviceId', isEqualTo: deviceId)
          .get();
      
      final docs = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
        'timestamp': (doc.data()['timestamp'] as Timestamp?)?.toDate().toIso8601String(),
      }).toList();
      
      // Sort locally by timestamp descending
      docs.sort((a, b) {
        final aDate = a['timestamp'] as String?;
        final bDate = b['timestamp'] as String?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      
      return docs.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Error getting activity logs: $e');
      return [];
    }
  }

  // ========== CONTACT & SUPPORT ==========
  
  /// Send contact message (saves to Firestore, admin dashboard will handle email sending)
  Future<Map<String, dynamic>> sendContactMessage({
    required String category,
    required String subject,
    required String message,
    required String deviceId,
    required String email,
  }) async {
    try {
      final deviceDoc = await _firestore.collection('devices').doc(deviceId).get();
      final deviceData = deviceDoc.data();
      
      // Save contact message to Firestore
      final docRef = await _firestore.collection('contact_messages').add({
        'deviceId': deviceId,
        'deviceModel': deviceData?['deviceModel'] ?? 'Unknown',
        'email': email,
        'category': category,
        'subject': subject,
        'message': message,
        'status': 'pending', // pending, replied, resolved
        'createdAt': FieldValue.serverTimestamp(),
        'replies': [],
      });
      
      debugPrint('✅ Contact message saved: ${docRef.id}');
      
      return {'success': true, 'messageId': docRef.id};
    } catch (e) {
      debugPrint('❌ Error sending contact message: $e');
      if (e.toString().contains('permission-denied')) {
        return {'success': false, 'error': 'Permission denied. Please restart the app.'};
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send live chat message
  Future<Map<String, dynamic>> sendLiveChatMessage({
    required String deviceId,
    required String message,
  }) async {
    try {
      debugPrint('📤 Sending live chat message from device: $deviceId');
      
      // Get device info (optional, for deviceModel)
      String? deviceModel;
      try {
        final deviceDoc = await _firestore.collection('devices').doc(deviceId).get();
        deviceModel = deviceDoc.data()?['deviceModel'] ?? 'Unknown';
      } catch (e) {
        debugPrint('⚠️ Could not fetch device info: $e');
        deviceModel = 'Unknown';
      }
      
      // Get chat document reference
      final chatRef = _firestore.collection('live_chats').doc(deviceId);
      
      // Get or create chat thread
      final chatDoc = await chatRef.get();
      if (!chatDoc.exists) {
        debugPrint('📝 Creating new chat thread for device: $deviceId');
        await chatRef.set({
          'deviceId': deviceId,
          'deviceModel': deviceModel,
          'status': 'active', // active, resolved, closed
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageAt': FieldValue.serverTimestamp(),
          'messages': [],
        });
        debugPrint('✅ Chat thread created');
      }
      
      // Add message to thread
      // Note: Cannot use FieldValue.serverTimestamp() inside arrayUnion
      // Use Timestamp.now() instead
      final now = Timestamp.now();
      final messageData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'sender': 'user',
        'senderId': deviceId,
        'message': message,
        'timestamp': now,
        'read': false,
      };
      
      debugPrint('💬 Adding message to chat thread...');
      await chatRef.update({
        'messages': FieldValue.arrayUnion([messageData]),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      
      debugPrint('✅ Live chat message sent successfully');
      
      return {'success': true};
    } catch (e) {
      debugPrint('❌ Error sending live chat message: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Error details: ${e.toString()}');
      
      String errorMessage = 'Failed to send message. Please try again.';
      
      if (e.toString().contains('permission-denied') || 
          e.toString().contains('PERMISSION_DENIED')) {
        errorMessage = 'Permission denied. Please restart the app and try again.';
      } else if (e.toString().contains('network') || 
                 e.toString().contains('unavailable')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      
      return {'success': false, 'error': errorMessage};
    }
  }

  /// Get live chat messages for device
  Stream<Map<String, dynamic>?> getLiveChatStream(String deviceId) {
    return _firestore
        .collection('live_chats')
        .doc(deviceId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return {
              'id': snapshot.id,
              ...snapshot.data()!,
            };
          }
          return null;
        });
  }
}

