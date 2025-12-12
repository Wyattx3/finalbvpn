import 'dart:async';
import 'package:flutter/material.dart';
import 'services/firebase_service.dart';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserManager {
  static final UserManager _instance = UserManager._internal();
  factory UserManager() => _instance;
  UserManager._internal() {
    _initFirebaseSync();
    loadRecentLocation();
    _loadSettings();
  }

  final FirebaseService _firebase = FirebaseService();

  // App Settings
  final ValueNotifier<String> currentLanguage = ValueNotifier('English');
  final ValueNotifier<Locale> currentLocale = ValueNotifier(const Locale('en', 'US'));

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Language
      final lang = prefs.getString('app_language') ?? 'English';
      currentLanguage.value = lang;
      _updateLocale(lang);
      
      // Load Split Tunneling
      final splitMode = prefs.getInt('split_tunneling_mode') ?? 0;
      splitTunnelingMode.value = splitMode;
      
      debugPrint('⚙️ Settings loaded: Language=$lang, SplitMode=$splitMode');
    } catch (e) {
      debugPrint('❌ Error loading settings: $e');
    }
  }

  // ========== ONBOARDING ==========
  
  /// Check if user has completed onboarding (new user = false)
  Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('onboarding_completed') ?? false;
    } catch (e) {
      debugPrint('❌ Error checking onboarding status: $e');
      return false;
    }
  }
  
  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      debugPrint('✅ Onboarding marked as completed');
    } catch (e) {
      debugPrint('❌ Error saving onboarding status: $e');
    }
  }

  Future<void> setLanguage(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', language);
      currentLanguage.value = language;
      _updateLocale(language);
      debugPrint('✅ Language saved: $language');
    } catch (e) {
      debugPrint('❌ Error saving language: $e');
    }
  }

  void _updateLocale(String language) {
    Locale newLocale;
    switch (language) {
      case 'Myanmar (Zawgyi)':
      case 'Myanmar (Unicode)':
        newLocale = const Locale('my', 'MM');
        break;
      case 'Japanese':
        newLocale = const Locale('ja', 'JP');
        break;
      case 'Chinese':
        newLocale = const Locale('zh', 'CN');
        break;
      case 'Thai':
        newLocale = const Locale('th', 'TH');
        break;
      default:
        newLocale = const Locale('en', 'US');
    }
    
    debugPrint('🌐 _updateLocale: $language -> ${newLocale.languageCode}_${newLocale.countryCode}');
    debugPrint('🌐 Old locale: ${currentLocale.value.languageCode}_${currentLocale.value.countryCode}');
    
    // Force notify by setting value
    currentLocale.value = newLocale;
    
    debugPrint('🌐 New locale set: ${currentLocale.value.languageCode}_${currentLocale.value.countryCode}');
  }

  // Recent Location Persistence
  final ValueNotifier<Map<String, dynamic>?> recentLocation = ValueNotifier(null);

  Future<void> loadRecentLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedLocation = prefs.getString('recent_location');
      debugPrint('📍 Raw saved location from prefs: $savedLocation');
      
      if (savedLocation != null && savedLocation.isNotEmpty) {
        final dynamic decoded = jsonDecode(savedLocation);
        
        // Ensure proper type casting
        if (decoded is Map<String, dynamic>) {
          recentLocation.value = decoded;
          debugPrint('📍 Loaded recent location: ${decoded['name']}');
        } else if (decoded is Map) {
          // Cast from Map<dynamic, dynamic> to Map<String, dynamic>
          final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);
          recentLocation.value = data;
          debugPrint('📍 Loaded recent location (casted): ${data['name']}');
        } else {
          debugPrint('❌ Invalid recent location format: ${decoded.runtimeType}');
        }
      } else {
        debugPrint('📍 No recent location saved yet');
      }
    } catch (e) {
      debugPrint('❌ Error loading recent location: $e');
      // Clear potentially corrupted data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('recent_location');
      } catch (_) {}
    }
  }

  Future<void> saveRecentLocation(Map<String, dynamic> server) async {
    try {
      debugPrint('📍 Attempting to save recent location...');
      debugPrint('📍 Server data: id=${server['id']}, country=${server['country']}, name=${server['name']}, flag=${server['flag']}');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Extract only JSON-serializable fields (avoid Timestamp and other Firebase types)
      final Map<String, dynamic> safeServerData = {
        'id': server['id']?.toString(),
        'name': server['name']?.toString(),
        'country': server['country']?.toString(),
        'flag': server['flag']?.toString() ?? '🌍',
        'address': server['address']?.toString(),
        'port': server['port'] is int ? server['port'] : int.tryParse(server['port']?.toString() ?? '443') ?? 443,
        'uuid': server['uuid']?.toString(),
        'path': server['path']?.toString(),
        'status': server['status']?.toString(),
        'load': server['load']?.toString(),
      };
      
      // Save relevant info for display
      final locationData = {
        'id': safeServerData['id'],
        'name': '${safeServerData['country']} - ${safeServerData['name']}', // Combined name
        'flag': safeServerData['flag'],
        'country': safeServerData['country'],
        // Save safe server data for reconnection
        'server_data': safeServerData,
      };
      
      final jsonString = jsonEncode(locationData);
      debugPrint('📍 JSON to save: $jsonString');
      
      await prefs.setString('recent_location', jsonString);
      recentLocation.value = locationData;
      debugPrint('✅ Recent location saved successfully: ${locationData['name']}');
    } catch (e, stack) {
      debugPrint('❌ Error saving recent location: $e');
      debugPrint('❌ Stack trace: $stack');
    }
  }


  // Balance (Points) - 1 Ad = 30 Points (30 Points = 30 MMK)
  final ValueNotifier<int> balancePoints = ValueNotifier(0);
  
  // Cooldown tracking (synced from Firebase)
  final ValueNotifier<int> cooldownRemaining = ValueNotifier(0);
  final ValueNotifier<bool> isInCooldown = ValueNotifier(false);
  
  // Today's earnings tracking (synced with Firebase)
  final ValueNotifier<int> todayEarnings = ValueNotifier(0);
  final ValueNotifier<int> adsWatchedToday = ValueNotifier(0);
  StreamSubscription? _dailyStatsSubscription;
  
  // VPN Remaining Time (Seconds) - Synced with Firebase
  final ValueNotifier<int> remainingSeconds = ValueNotifier(0);
  StreamSubscription<int>? _vpnTimeSubscription;
  Timer? _vpnSyncTimer; // Periodic sync timer
  bool _isTimerRunning = false; // Track if local timer is actively running

  // Split Tunneling Mode: 0 = Disable, 1 = Uses VPN, 2 = Bypass VPN
  final ValueNotifier<int> splitTunnelingMode = ValueNotifier(0);
  
  // Split Tunneling App Lists (package names)
  List<String> _usesVpnApps = [];
  List<String> _bypassVpnApps = [];
  
  /// Set split tunneling app lists
  void setSplitTunnelingApps({
    required List<String> usesVpnApps,
    required List<String> bypassVpnApps,
  }) {
    _usesVpnApps = usesVpnApps;
    _bypassVpnApps = bypassVpnApps;
    debugPrint('📱 Split tunneling apps updated: ${usesVpnApps.length} uses VPN, ${bypassVpnApps.length} bypass VPN');
  }
  
  /// Get the list of apps to block from VPN (for flutter_v2ray blockedApps)
  /// Returns null if split tunneling is disabled
  /// Returns package names of apps that should NOT use VPN
  List<String>? getBlockedApps() {
    switch (splitTunnelingMode.value) {
      case 0: // Disabled - all apps use VPN
        return null;
      case 1: // Only selected apps use VPN - block all others
        // This is complex - we need to return all apps EXCEPT _usesVpnApps
        // flutter_v2ray blockedApps means apps that are blocked from VPN
        // So if mode=1, we want only _usesVpnApps to use VPN, meaning we block everything else
        // However, we don't have the full list of all apps here
        // For simplicity, return null and let flutter_v2ray handle it differently
        // Or we can use a different approach - return _usesVpnApps as "allowed" apps
        return null; // TODO: This mode requires flutter_v2ray to support "allowedApps"
      case 2: // Bypass VPN for selected apps - these apps don't use VPN
        return _bypassVpnApps.isEmpty ? null : _bypassVpnApps;
      default:
        return null;
    }
  }

  // Display Latency Setting
  final ValueNotifier<bool> displayLatency = ValueNotifier(true);
  
  // VPN Protocol Setting: 0 = Auto, 1 = TCP, 2 = UDP (QUIC)
  final ValueNotifier<int> vpnProtocol = ValueNotifier(0);
  
  /// Get the port to use based on selected protocol
  /// Auto (0) uses WebSocket on 443
  /// TCP (1) uses raw TCP on 8443
  /// UDP (2) uses QUIC on 4434
  int getPortForProtocol() {
    switch (vpnProtocol.value) {
      case 1: return 8443;  // TCP
      case 2: return 4434;  // UDP (QUIC)
      default: return 443;  // Auto (WebSocket)
    }
  }
  
  /// Get the network type for V2Ray based on selected protocol
  String getNetworkForProtocol() {
    switch (vpnProtocol.value) {
      case 1: return 'tcp';
      case 2: return 'quic';
      default: return 'ws';
    }
  }
  
  /// Get protocol name for display
  String getProtocolName() {
    switch (vpnProtocol.value) {
      case 1: return 'TCP';
      case 2: return 'UDP (QUIC)';
      default: return 'Auto (WebSocket)';
    }
  }
  
  Timer? _timer;
  StreamSubscription? _balanceSubscription;
  VoidCallback? onTimeExpired; // Callback to disconnect VPN

  // Initialize Firebase balance sync
  void _initFirebaseSync() {
    // Listen to real-time balance updates
    _balanceSubscription = _firebase.listenToBalance().listen((balance) {
      balancePoints.value = balance;
    });
    
    // Listen to daily stats updates from Firebase
    _dailyStatsSubscription = _firebase.listenToDailyStats().listen((stats) {
      todayEarnings.value = stats['todayEarnings'] ?? 0;
      adsWatchedToday.value = stats['adsWatchedToday'] ?? 0;
      debugPrint('📊 Daily stats synced: ${todayEarnings.value} earned, ${adsWatchedToday.value} ads');
    });
    
    // Listen to VPN time updates from Firebase
    _vpnTimeSubscription = _firebase.listenToVpnTime().listen(
      (seconds) {
        final currentSeconds = remainingSeconds.value;
        final difference = (seconds - currentSeconds).abs();
        
        // SECURITY: Determine if this is an admin action that should be applied immediately
        // Admin actions that MUST be applied:
        // 1. Time set to 0 (admin revoked access)
        // 2. Time significantly REDUCED (admin reduced time - could be punishment/correction)
        // 3. Time significantly INCREASED (admin added bonus time)
        
        final bool isTimeRevoked = seconds == 0 && currentSeconds > 0;
        final bool isTimeReduced = seconds < currentSeconds && (currentSeconds - seconds) > 30;
        final bool isTimeIncreased = seconds > currentSeconds && (seconds - currentSeconds) > 60;
        final bool isAdminAction = isTimeRevoked || isTimeReduced || isTimeIncreased;
        
        if (!_isTimerRunning) {
          // Timer not running - always safe to update from Firebase
          remainingSeconds.value = seconds;
          debugPrint('⏱️ VPN time from Firebase (timer stopped): $seconds seconds');
        } else if (isTimeRevoked) {
          // CRITICAL: Admin revoked all time - must disconnect immediately
          remainingSeconds.value = 0;
          debugPrint('🚫 VPN time REVOKED by admin! Forcing disconnect...');
          // Trigger time expired callback to disconnect VPN
          _isTimerRunning = false;
          _timer?.cancel();
          _vpnSyncTimer?.cancel();
          if (onTimeExpired != null) {
            onTimeExpired!();
          }
        } else if (isTimeReduced) {
          // Admin reduced time - apply immediately (could be correction/punishment)
          remainingSeconds.value = seconds;
          debugPrint('⚠️ VPN time REDUCED by admin: $currentSeconds → $seconds seconds');
        } else if (isTimeIncreased) {
          // Admin added bonus time - apply immediately
          remainingSeconds.value = seconds;
          debugPrint('🎁 VPN time INCREASED by admin: $currentSeconds → $seconds seconds');
        }
        // Otherwise, ignore minor differences (sync delays) - local timer takes priority
      },
      onError: (e) {
        debugPrint('❌ Error listening to VPN time: $e');
      },
    );
    
    // Initial balance fetch
    _fetchBalance();
    _fetchVpnTime();
  }

  Future<void> _fetchBalance() async {
    try {
      final balance = await _firebase.getBalance();
      balancePoints.value = balance;
      print('💰 Balance fetched: $balance points');
    } catch (e) {
      print('❌ Error fetching balance: $e');
    }
  }

  Future<void> _fetchVpnTime() async {
    try {
      final seconds = await _firebase.getVpnRemainingSeconds();
      remainingSeconds.value = seconds;
      print('⏱️ VPN time fetched: $seconds seconds');
    } catch (e) {
      print('❌ Error fetching VPN time: $e');
    }
  }

  // Add Reward & Time - VPN page ads give both points AND VPN time
  Future<bool> watchAdReward() async {
    try {
      debugPrint('💰 VPN Page: Adding reward with VPN time bonus');
      final result = await _firebase.addAdReward(addVpnTime: true);
      if (result['success'] == true) {
        // VPN time is now stored in Firebase - update local value from server response
        final newVpnSeconds = (result['vpnRemainingSeconds'] as int?) ?? remainingSeconds.value;
        remainingSeconds.value = newVpnSeconds;
        debugPrint('⏱️ VPN time updated from server: $newVpnSeconds seconds');
        
        // Update cooldown from server response (use SDUI config value)
        if (result['cooldownStarted'] == true) {
          isInCooldown.value = true;
          cooldownRemaining.value = (result['cooldownDuration'] as num?)?.toInt() ?? 600; // From SDUI config
          debugPrint('⏰ Cooldown started: ${cooldownRemaining.value} seconds');
        }
        return true;
      } else {
        // Handle server errors
        if (result['error'] == 'cooldown') {
          isInCooldown.value = true;
          cooldownRemaining.value = result['cooldownRemaining'] ?? 0;
        }
      }
    } catch (e) {
      debugPrint('Error watching ad reward: $e');
    }
    return false;
  }

  // Add balance only (for earn money screen) - ALL validation server-side
  /// Add balance for watching ad
  /// [amount] - Reward amount (from SDUI config)
  /// [addVpnTime] - Whether to add VPN time bonus (only true for VPN page ads when no time left)
  Future<Map<String, dynamic>> addBalance(int amount, {bool addVpnTime = false}) async {
    try {
      debugPrint('💰 addBalance called - amount: $amount, addVpnTime: $addVpnTime');
      final result = await _firebase.addAdReward(rewardAmount: amount, addVpnTime: addVpnTime);
      
      if (result['success'] == true) {
        // Cooldown started? (use SDUI config value)
        if (result['cooldownStarted'] == true) {
          isInCooldown.value = true;
          cooldownRemaining.value = (result['cooldownDuration'] as num?)?.toInt() ?? 600; // From SDUI config
          debugPrint('⏰ Cooldown started: ${cooldownRemaining.value} seconds');
        }
        return {'success': true};
      } else {
        // Handle server-side errors
        if (result['error'] == 'cooldown') {
          isInCooldown.value = true;
          cooldownRemaining.value = result['cooldownRemaining'] ?? 0;
        }
        return result;
      }
    } catch (e) {
      debugPrint('Error adding balance: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Check if user can watch ad - SERVER-SIDE validation
  Future<Map<String, dynamic>> canWatchAdAsync() async {
    final result = await _firebase.canWatchAd();
    
    if (result['canWatch'] == false && result['reason'] == 'cooldown') {
      isInCooldown.value = true;
      cooldownRemaining.value = result['cooldownRemaining'] ?? 0;
    } else {
      isInCooldown.value = false;
      cooldownRemaining.value = 0;
    }
    
    return result;
  }

  // Get remaining cooldown time (synced from Firebase)
  Duration get cooldownTime => Duration(seconds: cooldownRemaining.value);

  // Start Countdown - Syncs to Firebase every 30 seconds
  void startTimer() {
    // Cancel any existing timers first
    _timer?.cancel();
    _vpnSyncTimer?.cancel();
    
    // Mark timer as running - this prevents Firebase listener from interfering
    _isTimerRunning = true;
    debugPrint('⏱️ Timer starting... remaining: ${remainingSeconds.value} seconds');
    
    // Local countdown timer (every second)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      } else {
        // Time expired
        _isTimerRunning = false;
        _timer?.cancel();
        _vpnSyncTimer?.cancel();
        // Sync final time to Firebase
        _firebase.syncVpnTime(0);
        debugPrint('⏱️ Timer expired - auto disconnecting');
        if (onTimeExpired != null) {
          onTimeExpired!(); // Auto disconnect
        }
      }
    });
    
    // Sync to Firebase every 30 seconds to reduce write operations
    _vpnSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (remainingSeconds.value > 0 && _isTimerRunning) {
        _firebase.syncVpnTime(remainingSeconds.value);
        debugPrint('⏱️ Synced to Firebase: ${remainingSeconds.value} seconds');
      }
    });
    
    debugPrint('⏱️ Timer started successfully');
  }

  // Stop Countdown and sync final time to Firebase
  void stopTimer() {
    // Mark timer as stopped FIRST - allows Firebase listener to update again
    _isTimerRunning = false;
    
    _timer?.cancel();
    _vpnSyncTimer?.cancel();
    
    // Sync current time to Firebase when stopping
    if (remainingSeconds.value > 0) {
      _firebase.syncVpnTime(remainingSeconds.value);
    }
    
    debugPrint('⏱️ Timer stopped, synced ${remainingSeconds.value} seconds to Firebase');
  }

  // Helper to format time
  String get formattedTime {
    int h = remainingSeconds.value ~/ 3600;
    int m = (remainingSeconds.value % 3600) ~/ 60;
    int s = remainingSeconds.value % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // Helper to convert to USD (1 Point = 1 MMK, 1 USD = 4500 MMK)
  double get balanceUSD => balancePoints.value / 4500;
  
  // Cleanup
  void dispose() {
    _timer?.cancel();
    _vpnSyncTimer?.cancel();
    _balanceSubscription?.cancel();
    _dailyStatsSubscription?.cancel();
    _vpnTimeSubscription?.cancel();
  }
  
  // Refresh balance from server
  Future<void> refreshBalance() async {
    await _fetchBalance();
  }
  
  // Refresh VPN time from server
  Future<void> refreshVpnTime() async {
    await _fetchVpnTime();
  }
}

