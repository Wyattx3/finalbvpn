import 'dart:async';
import 'package:flutter/material.dart';

class UserManager {
  static final UserManager _instance = UserManager._internal();
  factory UserManager() => _instance;
  UserManager._internal();

  // Balance (Points) - 1 Ad = 30 Points (30 Points = 30 MMK)
  // Test Balance: 100,000 Points
  final ValueNotifier<int> balancePoints = ValueNotifier(100000);
  
  // Ad Limits
  int _adWatchCount = 0;
  DateTime? _nextAdAvailableTime;
  
  // VPN Remaining Time (Seconds)
  final ValueNotifier<int> remainingSeconds = ValueNotifier(0);

  // Split Tunneling Mode: 0 = Disable, 1 = Uses VPN, 2 = Bypass VPN
  final ValueNotifier<int> splitTunnelingMode = ValueNotifier(0);

  // Display Latency Setting
  final ValueNotifier<bool> displayLatency = ValueNotifier(true);
  
  Timer? _timer;
  VoidCallback? onTimeExpired; // Callback to disconnect VPN

  // Add Reward & Time
  // Returns true if successful, false if limit reached
  bool watchAdReward() {
    if (!canWatchAd()) return false;

    balancePoints.value += 30; // Earn 30 Points
    remainingSeconds.value += 7200; // Add 2 Hours (7200 seconds)
    
    _adWatchCount++;
    if (_adWatchCount >= 10) {
      // 10 minutes cooldown after 10 ads
      _nextAdAvailableTime = DateTime.now().add(const Duration(minutes: 10));
      _adWatchCount = 0; // Reset count for next cycle
    }
    return true;
  }

  // Add balance only (for earn money screen)
  bool addBalance(int amount) {
    if (!canWatchAd()) return false;
    
    balancePoints.value += amount;
    
    _adWatchCount++;
    if (_adWatchCount >= 10) {
      _nextAdAvailableTime = DateTime.now().add(const Duration(minutes: 10));
      _adWatchCount = 0;
    }
    return true;
  }

  // Check if user can watch ad
  bool canWatchAd() {
    if (_nextAdAvailableTime != null) {
      if (DateTime.now().isBefore(_nextAdAvailableTime!)) {
        return false; // Still in cooldown
      } else {
        _nextAdAvailableTime = null; // Cooldown over
      }
    }
    return true;
  }

  // Get remaining cooldown time
  Duration get cooldownTime {
    if (_nextAdAvailableTime == null) return Duration.zero;
    final diff = _nextAdAvailableTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  // Start Countdown
  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      } else {
        _timer?.cancel();
        if (onTimeExpired != null) {
          onTimeExpired!(); // Auto disconnect
        }
      }
    });
  }

  // Stop Countdown
  void stopTimer() {
    _timer?.cancel();
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
}

