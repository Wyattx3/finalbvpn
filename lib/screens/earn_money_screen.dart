import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../user_manager.dart';
import '../services/mock_sdui_service.dart';
import '../utils/message_dialog.dart';
import 'dart:async';

class EarnMoneyScreen extends StatefulWidget {
  const EarnMoneyScreen({super.key});

  @override
  State<EarnMoneyScreen> createState() => _EarnMoneyScreenState();
}

class _EarnMoneyScreenState extends State<EarnMoneyScreen> {
  final UserManager _userManager = UserManager();
  final MockSduiService _sduiService = MockSduiService();
  
  bool _isWatchingAd = false;
  int _todayEarnings = 0;
  int _adsWatchedToday = 0;
  
  // SDUI Config
  int _maxAdsPerDay = 100;
  int _rewardPerAd = 30;
  String _currency = 'Points'; // Changed to Points
  Map<String, dynamic> _config = {};
  bool _isLoading = true;
  Timer? _timer; // For cooldown countdown

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
    // Start timer to update UI for cooldown countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_userManager.canWatchAd()) {
        setState(() {}); // Refresh UI to show countdown
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('earn_money');
      if (mounted) {
        if (response.containsKey('config')) {
          final config = response['config'];
          setState(() {
            _config = config;
            _maxAdsPerDay = config['max_ads_per_day'] ?? 100;
            _rewardPerAd = config['reward_per_ad'] ?? 30;
            _currency = 'Points'; // Force Points
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint("SDUI Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatNumber(int number) {
    String numStr = number.toString();
    String result = '';
    int count = 0;
    for (int i = numStr.length - 1; i >= 0; i--) {
      count++;
      result = numStr[i] + result;
      if (count % 3 == 0 && i != 0) {
        result = ',$result';
      }
    }
    return result;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _watchAd() {
    if (_isWatchingAd) return;
    
    // Check daily limit
    if (_adsWatchedToday >= _maxAdsPerDay) {
      showMessageDialog(
        context,
        message: 'You have reached the daily limit!',
        type: MessageType.warning,
        title: 'Daily Limit',
      );
      return;
    }

    // Check cooldown (User Manager Logic)
    if (!_userManager.canWatchAd()) {
      showMessageDialog(
        context,
        message: 'Please wait ${_formatDuration(_userManager.cooldownTime)} before watching another ad.',
        type: MessageType.info,
        title: 'Cooldown',
      );
      return;
    }

    setState(() {
      _isWatchingAd = true;
    });

    // Simulate watching ad
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        // Try to add balance (checks logic again internally)
        bool success = _userManager.addBalance(_rewardPerAd);
        
        if (success) {
          setState(() {
            _isWatchingAd = false;
            _todayEarnings += _rewardPerAd;
            _adsWatchedToday++;
          });
          showMessageDialog(
            context,
            message: '+$_rewardPerAd $_currency earned!',
            type: MessageType.success,
            title: 'Reward Earned',
          );
        } else {
           setState(() {
            _isWatchingAd = false;
          });
          // Should not happen if we checked canWatchAd before, but safety check
          showMessageDialog(
             context,
             message: 'Please wait before watching another ad.',
             type: MessageType.warning,
             title: 'Cooldown Active',
           );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final primaryPurple = isDark ? const Color(0xFFB388FF) : const Color(0xFF7E57C2);
    final surfaceColor = isDark ? const Color(0xFF2D2640) : Colors.white;
    
    final labels = _config['labels'] ?? {};
    
    // Check cooldown status for UI
    final bool inCooldown = !_userManager.canWatchAd();
    final Duration cooldown = _userManager.cooldownTime;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: backgroundColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          title: Text(_config['title'] ?? 'Earn Points', style: TextStyle(color: textColor)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Total Balance Section
                ValueListenableBuilder<int>(
                  valueListenable: _userManager.balancePoints, // Use balancePoints
                  builder: (context, balance, child) {
                    // 1 Point = 1 MMK (Approx)
                    // 1 USD = 4500 MMK
                    final usdValue = balance / 4500; 
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark 
                            ? [const Color(0xFF7C4DFF), const Color(0xFFB388FF)]
                            : [const Color(0xFF7E57C2), const Color(0xFFB39DDB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Total Points',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_formatNumber(balance)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '≈ ${_formatNumber(balance)} MMK / \$${usdValue.toStringAsFixed(2)} USD',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '1 Point = 1 MMK',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Today: +${_formatNumber(_todayEarnings)} $_currency',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: isDark ? Border.all(color: Colors.purple.withOpacity(0.2)) : null,
                          boxShadow: isDark ? null : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.play_circle_outline, color: primaryPurple, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              '$_adsWatchedToday / $_maxAdsPerDay',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ads Today',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: isDark ? Border.all(color: Colors.purple.withOpacity(0.2)) : null,
                          boxShadow: isDark ? null : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.star_border, color: Colors.amber, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              '$_rewardPerAd $_currency',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Per Ad',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Progress Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: isDark ? Border.all(color: Colors.purple.withOpacity(0.2)) : null,
                    boxShadow: isDark ? null : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daily Progress',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          Text(
                            '${(_adsWatchedToday / _maxAdsPerDay * 100).toInt()}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _adsWatchedToday / _maxAdsPerDay,
                          minHeight: 10,
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryPurple),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Max earnings today: ${_formatNumber(_maxAdsPerDay * _rewardPerAd)} $_currency',
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Watch Ad Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: (inCooldown || _adsWatchedToday >= _maxAdsPerDay) ? null : _watchAd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPurple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isWatchingAd
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Watching Ad...',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                inCooldown ? Icons.timer : Icons.play_circle_filled, 
                                size: 28,
                                color: inCooldown ? Colors.white70 : Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _adsWatchedToday >= _maxAdsPerDay 
                                    ? (labels['daily_limit_reached'] ?? 'Daily Limit Reached')
                                    : (inCooldown 
                                        ? 'Wait ${_formatDuration(cooldown)}'
                                        : (labels['watch_ad_button'] ?? 'Watch Ad & Earn $_rewardPerAd $_currency')),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Info Text
                Text(
                  'Watch short video ads to earn points.\nCooldown of 10 mins after every 10 ads.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
