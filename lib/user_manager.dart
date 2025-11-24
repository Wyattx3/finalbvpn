import 'dart:async';
import 'package:flutter/material.dart';

class UserManager {
  static final UserManager _instance = UserManager._internal();
  factory UserManager() => _instance;
  UserManager._internal();

  // Balance (MMK) - 1 Ad = 30 MMK
  // Test Balance: 100,000 MMK
  final ValueNotifier<int> balanceMMK = ValueNotifier(100000);
  
  // VPN Remaining Time (Seconds)
  final ValueNotifier<int> remainingSeconds = ValueNotifier(0);
  
  Timer? _timer;
  VoidCallback? onTimeExpired; // Callback to disconnect VPN

  // Add Reward & Time
  void watchAdReward() {
    balanceMMK.value += 30; // Earn 30 MMK
    remainingSeconds.value += 7200; // Add 2 Hours (7200 seconds)
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

  // Helper to convert to USD (1 USD = 4500 MMK)
  double get balanceUSD => balanceMMK.value / 4500; 
}

