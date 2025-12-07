import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:android_id/android_id.dart';

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
  /// Force refresh device ID (reload from system)
  Future<void> refreshDeviceId() async {
    _deviceId = null;
    debugPrint('📱 Refreshing device ID...');
    await getDeviceId();
  }
  
  /// Get PERMANENT device ID that survives app uninstall
  /// - Android: Uses ANDROID_ID (persists across reinstalls, resets on factory reset)
  /// - iOS: Uses identifierForVendor
  /// - Others: Uses platform-specific identifiers
  Future<String> getDeviceId() async {
    if (_deviceId != null) {
      return _deviceId!;
    }

    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        _deviceId = 'web${webInfo.userAgent?.hashCode.toRadixString(16) ?? DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
        _deviceModel = 'Web Browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        debugPrint('📱 Getting Android info...');
        debugPrint('📱 Brand: ${androidInfo.brand}, Model: ${androidInfo.model}');
        
        // Use ANDROID_ID - the REAL permanent ID that survives reinstalls!
        // Only resets on factory reset
        try {
          const androidIdPlugin = AndroidId();
          final androidId = await androidIdPlugin.getId();
          debugPrint('📱 AndroidId plugin returned: $androidId');
          _deviceId = androidId ?? 'android_${androidInfo.id}';
        } catch (e) {
          debugPrint('❌ AndroidId plugin error: $e');
          // Fallback to device fingerprint
          _deviceId = 'android_${androidInfo.id}';
        }
        _deviceModel = '${androidInfo.brand} ${androidInfo.model}';
        debugPrint('📱 Final Device ID: $_deviceId');
        debugPrint('📱 Device Model: $_deviceModel');
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // identifierForVendor persists across reinstalls for same vendor
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
      
      debugPrint('📱 Device ID: $_deviceId');
    } catch (e) {
      debugPrint('❌ Error getting device info: $e');
      _deviceId = 'err${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
      _deviceModel = 'Unknown Device';
    }

    return _deviceId!;
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

  // ========== IP/GEOLOCATION ==========
  
  /// Get IP address and country info from free API
  Future<Map<String, String>> _getIpInfo() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      
      final request = await client.getUrl(Uri.parse('http://ip-api.com/json/'));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = json.decode(responseBody) as Map<String, dynamic>;
        
        return {
          'ipAddress': data['query']?.toString() ?? '',
          'country': data['country']?.toString() ?? 'Unknown',
          'countryCode': data['countryCode']?.toString() ?? '',
          'city': data['city']?.toString() ?? '',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Could not get IP info: $e');
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
      
      // Get IP and geolocation info
      final ipInfo = await _getIpInfo();
      final flag = _getCountryFlag(ipInfo['countryCode'] ?? '');
      
      // Register/update device in Firestore directly
      debugPrint('🔥 Registering device to Firebase:');
      debugPrint('   - deviceId: $deviceId');
      debugPrint('   - deviceModel: $deviceModel');
      debugPrint('   - platform: ${_getPlatform()}');
      
      await _firestore.collection('devices').doc(deviceId).set({
        'deviceId': deviceId,
        'deviceModel': deviceModel,
        'platform': _getPlatform(),
        'appVersion': '1.0.0',
        'status': 'online',
        'ipAddress': ipInfo['ipAddress'],
        'country': ipInfo['country'],
        'countryCode': ipInfo['countryCode'],
        'city': ipInfo['city'],
        'flag': flag,
        'dataUsage': 0,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // 📝 Log login activity to Firebase
      await _logLoginActivity(deviceId, ipInfo, flag);
      
      _isInitialized = true;
      debugPrint('✅ Firebase initialized successfully!');
      debugPrint('📍 IP: ${ipInfo['ipAddress']}, Country: ${ipInfo['country']}');
      return true;
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
      // Get IP and geolocation info
      final ipInfo = await _getIpInfo();
      final flag = _getCountryFlag(ipInfo['countryCode'] ?? '');
      
      await _firestore.collection('devices').doc(deviceId).set({
        'deviceId': deviceId,
        'deviceModel': deviceModel,
        'platform': _getPlatform(),
        'appVersion': '1.0.0',
        'status': 'online',
        'balance': 0,
        'ipAddress': ipInfo['ipAddress'],
        'country': ipInfo['country'],
        'countryCode': ipInfo['countryCode'],
        'city': ipInfo['city'],
        'flag': flag,
        'dataUsage': 0,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
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

  // ========== SERVERS ==========
  
  /// Get all servers from Firestore
  Future<List<Map<String, dynamic>>> getServers() async {
    try {
      final snapshot = await _firestore
          .collection('servers')
          .where('status', isNotEqualTo: 'offline')
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting servers: $e');
      return [];
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
}

