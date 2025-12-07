import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../user_manager.dart';
import '../services/sdui_service.dart';
import '../utils/message_dialog.dart';
import '../utils/network_utils.dart';
import 'dart:async';

class EarnMoneyScreen extends StatefulWidget {
  const EarnMoneyScreen({super.key});

  @override
  State<EarnMoneyScreen> createState() => _EarnMoneyScreenState();
}

class _EarnMoneyScreenState extends State<EarnMoneyScreen> {
  final UserManager _userManager = UserManager();
  final SduiService _sduiService = SduiService();
  
  bool _isWatchingAd = false;
  
  // SDUI Config
  int _maxAdsPerDay = 100;
  int _rewardPerAd = 30;
  int _cooldownAdsCount = 10;
  int _cooldownMinutes = 10;
  String _currency = 'Points'; // Changed to Points
  Map<String, dynamic> _config = {};
  bool _isLoading = true;
  Timer? _timer; // For cooldown countdown
  StreamSubscription<Map<String, dynamic>>? _sduiSubscription;

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
    _checkCanWatchAd(); // Initial server check
    // Start timer to update UI for cooldown countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _userManager.isInCooldown.value) {
        // Decrement cooldown locally for smooth UI
        if (_userManager.cooldownRemaining.value > 0) {
          _userManager.cooldownRemaining.value--;
        } else {
          _userManager.isInCooldown.value = false;
        }
        setState(() {}); // Refresh UI
      }
    });
  }
  
  Future<void> _checkCanWatchAd() async {
    await _userManager.canWatchAdAsync();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sduiSubscription?.cancel();
    super.dispose();
  }

  void _loadServerConfig() {
    debugPrint('💰 EarnMoney: Starting SDUI real-time listener...');
    
    // Timeout fallback
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        debugPrint('⚠️ EarnMoney: SDUI timeout - showing default UI');
        setState(() => _isLoading = false);
      }
    });
    
    // Use real-time listener for SDUI updates
    _sduiSubscription = _sduiService.watchScreenConfig('earn_money').listen(
      (response) {
        debugPrint('💰 EarnMoney: Received SDUI update!');
        if (mounted) {
          if (response.containsKey('config')) {
            final config = response['config'];
            debugPrint('💰 EarnMoney: Config received - max_ads: ${config['max_ads_per_day']}, reward: ${config['reward_per_ad']}, cooldown_ads: ${config['cooldown_ads_count']}, cooldown_min: ${config['cooldown_minutes']}');
            setState(() {
              _config = config;
              // Cast to int to handle Firestore num/double values
              _maxAdsPerDay = (config['max_ads_per_day'] as num?)?.toInt() ?? 100;
              _rewardPerAd = (config['reward_per_ad'] as num?)?.toInt() ?? 30;
              _cooldownAdsCount = (config['cooldown_ads_count'] as num?)?.toInt() ?? 10;
              _cooldownMinutes = (config['cooldown_minutes'] as num?)?.toInt() ?? 10;
              _currency = 'Points'; // Force Points
              _isLoading = false;
            });
            debugPrint('✅ EarnMoney: UI updated - maxAds: $_maxAdsPerDay, reward: $_rewardPerAd, cooldownAds: $_cooldownAdsCount, cooldownMin: $_cooldownMinutes');
          } else {
            setState(() => _isLoading = false);
          }
        }
      },
      onError: (e) {
        debugPrint("❌ EarnMoney SDUI Error: $e");
        if (mounted) setState(() => _isLoading = false);
      },
    );
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

  void _watchAd() async {
    if (_isWatchingAd) return;
    
    // Check network connection first
    final hasConnection = await NetworkUtils.hasInternetConnection();
    if (!hasConnection) {
      if (mounted) {
        NetworkUtils.showNetworkErrorDialog(context, onRetry: _watchAd);
      }
      return;
    }
    
    setState(() {
      _isWatchingAd = true;
    });
    
    // SERVER-SIDE validation first
    final canWatch = await _userManager.canWatchAdAsync();
    
    if (canWatch['canWatch'] != true) {
      setState(() {
        _isWatchingAd = false;
      });
      
      if (canWatch['reason'] == 'daily_limit') {
        showMessageDialog(
          context,
          message: 'You have reached the daily limit!',
          type: MessageType.warning,
          title: 'Daily Limit',
        );
      } else if (canWatch['reason'] == 'cooldown') {
        showMessageDialog(
          context,
          message: 'Please wait ${_formatDuration(_userManager.cooldownTime)} before watching another ad.',
          type: MessageType.info,
          title: 'Cooldown',
        );
      }
      return;
    }

    // Simulate watching ad
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      setState(() {
        _isWatchingAd = false;
      });
      
      // Show reward dialog - only add points when user taps OK
      // Earn Money screen: ONLY POINTS, NO VPN TIME
      showMessageDialog(
        context,
        message: '+$_rewardPerAd $_currency earned!',
        type: MessageType.success,
        title: 'Reward Earned',
        onOkPressed: () async {
          debugPrint('💰 Earn Money: Adding $_rewardPerAd points (no VPN time)');
          // SERVER-SIDE: Add balance (ONLY POINTS, no VPN time for Earn Money screen)
          final result = await _userManager.addBalance(_rewardPerAd, addVpnTime: false);
          
          if (result['success'] != true) {
            if (mounted) {
              showMessageDialog(
                context,
                message: result['message'] ?? 'Failed to add reward',
                type: MessageType.error,
                title: 'Error',
              );
            }
          }
        },
      );
    }
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
    
    // Check cooldown status for UI (from Firebase)
    final bool inCooldown = _userManager.isInCooldown.value;
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
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Total Balance Section
                ValueListenableBuilder<int>(
                  valueListenable: _userManager.balancePoints,
                  builder: (context, balance, child) {
                    final usdValue = balance / 4500; 
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                          const Text('Total Points', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            '${_formatNumber(balance)}',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '≈ ${_formatNumber(balance)} MMK / \$${usdValue.toStringAsFixed(2)} USD',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text('1 Point = 1 MMK', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                          const SizedBox(height: 12),
                          ValueListenableBuilder<int>(
                            valueListenable: _userManager.todayEarnings,
                            builder: (context, todayEarned, child) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Today: +${_formatNumber(todayEarned)} $_currency',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Stats Row - with ValueListenableBuilder for real-time updates
                ValueListenableBuilder<int>(
                  valueListenable: _userManager.adsWatchedToday,
                  builder: (context, adsWatched, child) {
                    return Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: isDark ? Border.all(color: Colors.purple.withOpacity(0.2)) : null,
                              boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.play_circle_outline, color: primaryPurple, size: 24),
                                const SizedBox(height: 6),
                                Text('$adsWatched / $_maxAdsPerDay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                                const SizedBox(height: 2),
                                Text('Ads Today', style: TextStyle(color: subtitleColor, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: isDark ? Border.all(color: Colors.purple.withOpacity(0.2)) : null,
                              boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.star_border, color: Colors.amber, size: 24),
                                const SizedBox(height: 6),
                                Text('$_rewardPerAd $_currency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                                const SizedBox(height: 2),
                                Text('Per Ad', style: TextStyle(color: subtitleColor, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Progress Bar - with ValueListenableBuilder
                ValueListenableBuilder<int>(
                  valueListenable: _userManager.adsWatchedToday,
                  builder: (context, adsWatched, child) {
                    final progress = adsWatched / _maxAdsPerDay;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: isDark ? Border.all(color: Colors.purple.withOpacity(0.2)) : null,
                        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Daily Progress', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 13)),
                              Text('${(progress * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: primaryPurple)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryPurple),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Max earnings today: ${_formatNumber(_maxAdsPerDay * _rewardPerAd)} $_currency', style: TextStyle(color: subtitleColor, fontSize: 11)),
                        ],
                      ),
                    );
                  },
                ),

                const Spacer(),

                // Watch Ad Button - with ValueListenableBuilder
                ValueListenableBuilder<int>(
                  valueListenable: _userManager.adsWatchedToday,
                  builder: (context, adsWatched, child) {
                    final limitReached = adsWatched >= _maxAdsPerDay;
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (inCooldown || limitReached) ? null : _watchAd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isWatchingAd
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                  SizedBox(width: 10),
                                  Text('Watching Ad...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(inCooldown ? Icons.timer : Icons.play_circle_filled, size: 24, color: inCooldown ? Colors.white70 : Colors.white),
                                  const SizedBox(width: 10),
                                  Text(
                                    limitReached 
                                        ? (labels['daily_limit_reached'] ?? 'Daily Limit Reached')
                                        : (inCooldown ? 'Wait ${_formatDuration(cooldown)}' : (labels['watch_ad_button'] ?? 'Watch Ad & Earn $_rewardPerAd $_currency')),
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),

                // Info Text
                Text(
                  'Cooldown of 10 mins after every 10 ads.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subtitleColor, fontSize: 11),
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
