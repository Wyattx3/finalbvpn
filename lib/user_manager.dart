import 'dart:async';
import 'package:flutter/material.dart';
import 'services/firebase_service.dart';

class UserManager {
  static final UserManager _instance = UserManager._internal();
  factory UserManager() => _instance;
  UserManager._internal() {
    _initFirebaseSync();
  }

  final FirebaseService _firebase = FirebaseService();

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

  // Split Tunneling Mode: 0 = Disable, 1 = Uses VPN, 2 = Bypass VPN
  final ValueNotifier<int> splitTunnelingMode = ValueNotifier(0);

  // Display Latency Setting
  final ValueNotifier<bool> displayLatency = ValueNotifier(true);
  
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
        
        // Update in these cases:
        // 1. Timer is not running
        // 2. Significant difference (admin made changes) - more than 60 seconds
        if (_timer == null || !_timer!.isActive || difference > 60) {
          remainingSeconds.value = seconds;
          debugPrint('⏱️ VPN time from Firebase: $seconds seconds (diff: $difference)');
          if (difference > 60) {
            debugPrint('⏱️ Significant change detected - admin adjustment applied!');
          }
        }
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
    _timer?.cancel();
    _vpnSyncTimer?.cancel();
    
    // Local countdown timer (every second)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      } else {
        _timer?.cancel();
        _vpnSyncTimer?.cancel();
        // Sync final time to Firebase
        _firebase.syncVpnTime(0);
        if (onTimeExpired != null) {
          onTimeExpired!(); // Auto disconnect
        }
      }
    });
    
    // Sync to Firebase every 30 seconds to reduce write operations
    _vpnSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (remainingSeconds.value > 0) {
        _firebase.syncVpnTime(remainingSeconds.value);
      }
    });
    
    debugPrint('⏱️ Timer started with Firebase sync');
  }

  // Stop Countdown and sync final time to Firebase
  void stopTimer() {
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

