import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'settings_screen.dart';
import 'location_selection_screen.dart';
import 'rewards_screen.dart';
import 'earn_money_screen.dart';
import '../user_manager.dart';
import '../services/mock_sdui_service.dart';
import '../utils/message_dialog.dart';
import '../utils/review_utils.dart'; // Import ReviewUtils
import 'dynamic_popup_screen.dart';
import 'dart:async';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isConnected = false;
  bool isConnecting = false;
  String currentLocation = 'US - San Jose';
  String currentFlag = '🇺🇸';
  
  final UserManager _userManager = UserManager();
  final MockSduiService _sduiService = MockSduiService();
  static const platform = MethodChannel('com.example.vpn_app/notification');

  // SDUI Config
  Map<String, dynamic> _config = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Load SDUI Config
    _loadServerConfig();
    
    // Check for Dynamic Popup (Update/Ban/Promo)
    _checkStartupPopup();

    // Check for Review Request (after 48h)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkReviewRequest();
      _requestPermission();
    });

    _userManager.onTimeExpired = () {
      if (mounted && isConnected) {
        setState(() {
          isConnected = false;
        });
        showMessageDialog(
          context,
          message: 'Time expired! Watch ads to reconnect.',
          type: MessageType.warning,
          title: 'Time Expired',
        );
        _stopNotification();
      }
    };
  }

  Future<void> _checkReviewRequest() async {
    // Uncomment the line below to RESET for testing purposes (will set install time to 49h ago)
    await ReviewUtils.debugResetForTesting(); 
    
    if (mounted) {
      await ReviewUtils.checkAndRequestReview(context);
    }
  }

  Future<void> _checkStartupPopup() async {
    try {
      final response = await _sduiService.getScreenConfig('popup_startup');
      if (mounted && response.containsKey('config')) {
        final config = response['config'];
        
        // Check if popup is enabled from server
        final bool isEnabled = config['enabled'] ?? false;
        
        if (isEnabled) {
          showDynamicPopup(context, config);
        }
      }
    } catch (e) {
      debugPrint("Popup Error: $e");
    }
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('home');
      if (mounted) {
        setState(() {
          _config = response['config'] ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("SDUI Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermission() async {
    try {
      await platform.invokeMethod('requestPermission');
    } on PlatformException catch (e) {
      debugPrint("Failed to request permission: '${e.message}'.");
    }
  }

  @override
  void dispose() {
    _userManager.stopTimer();
    _stopNotification();
    super.dispose();
  }
  
  Future<void> _startNotification() async {
    try {
      await platform.invokeMethod('startNotification', {
        'location': currentLocation,
        'flag': currentFlag,
        'remaining_seconds': _userManager.remainingSeconds.value,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to start notification: '${e.message}'.");
    }
  }

  Future<void> _stopNotification() async {
    try {
      await platform.invokeMethod('stopNotification');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop notification: '${e.message}'.");
    }
  }

  void _toggleConnection() {
    if (isConnecting) return;

    if (isConnected) {
      _userManager.stopTimer();
      setState(() {
        isConnected = false;
      });
      _stopNotification();
    } else {
      if (_userManager.remainingSeconds.value > 0) {
        _simulateConnection();
      } else {
        _showAdDialog();
      }
    }
  }

  void _simulateConnection() {
    setState(() {
      isConnecting = true;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          isConnecting = false;
          isConnected = true;
        });
        _userManager.startTimer();
        _startNotification();
      }
    });
  }

  void _showAdDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_off, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Out of Time!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Watch a short ad to get 2 hours of VPN time and earn 30 MMK.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _simulateAdWatch();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.play_circle_fill),
                  label: const Text('Watch Ad'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _simulateAdWatch() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Watching Ad...'),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context);
        _userManager.watchAdReward();
        
        showMessageDialog(
          context,
          message: '+2 Hours Added, +30 MMK Earned',
          type: MessageType.success,
          title: 'Reward Earned!',
        );

        _simulateConnection();
      }
    });
  }

  Future<void> _openLocationSelection() async {
    if (isConnected) {
      showMessageDialog(
        context,
        message: 'Please disconnect to change location',
        type: MessageType.info,
        title: 'Disconnect First',
      );
      return;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationSelectionScreen()),
    );

    if (result != null && result is Map) {
      setState(() {
        currentLocation = result['location'];
        currentFlag = result['flag'] ?? '🏳️';
      });
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
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF352F44) : Colors.white;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey;
    final backgroundColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);

    // SDUI Strings with fallbacks
    final appBarConfig = _config['app_bar'] ?? {};
    final buttonConfig = _config['main_button'] ?? {};
    final cardConfig = _config['location_card'] ?? {};

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.monetization_on_outlined, color: isDark ? const Color(0xFFB388FF) : const Color(0xFF7E57C2)),
          tooltip: 'Earn Money',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EarnMoneyScreen()),
            );
          },
        ),
        title: ValueListenableBuilder<int>(
          valueListenable: _userManager.splitTunnelingMode,
          builder: (context, splitMode, child) {
            final titleColor = isConnecting ? Colors.orange : (isConnected ? Colors.green : (isDark ? Colors.white : Colors.black));
            
            String titleText = appBarConfig['title_disconnected'] ?? 'Not Connected';
            if (isConnecting) titleText = appBarConfig['title_connecting'] ?? 'Connecting...';
            if (isConnected) titleText = appBarConfig['title_connected'] ?? 'Connected';

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (splitMode != 0) ...[
                  const SizedBox(width: 8),
                  Icon(
                    splitMode == 1 ? Icons.filter_list : Icons.block,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ],
              ],
            );
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.card_giftcard, color: isDark ? const Color(0xFFB388FF) : const Color(0xFF7E57C2)),
            tooltip: 'Withdraw',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RewardsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(CupertinoIcons.settings, color: textColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive calculations
          final double screenHeight = constraints.maxHeight;
          final double buttonSize = screenHeight * 0.25; // Button is 25% of screen height
          final double innerButtonSize = buttonSize * 0.75; 
          
          return ValueListenableBuilder<int>(
            valueListenable: _userManager.remainingSeconds,
            builder: (context, remainingSeconds, child) {
              return Column(
                children: [
                  // Top Section: Timer (Flexible space)
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: remainingSeconds > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: isDark ? Border.all(color: Colors.deepPurple.withOpacity(0.3)) : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer, size: 16, color: Colors.deepPurple),
                                const SizedBox(width: 8),
                                Text(
                                  _userManager.formattedTime,
                                  style: const TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(), 
                    ),
                  ),

                  // Middle Section: Power Button & Text (Largest Space)
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Power Button
                        GestureDetector(
                          onTap: _toggleConnection,
                          child: Container(
                            width: buttonSize,
                            height: buttonSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected 
                                  ? Colors.green.withOpacity(0.1) 
                                  : (isConnecting ? Colors.orange.withOpacity(0.1) : (isDark ? Colors.grey.withOpacity(0.1) : Colors.grey.withOpacity(0.1))),
                              boxShadow: [
                                BoxShadow(
                                  color: isConnected 
                                      ? Colors.green.withOpacity(0.2) 
                                      : (isConnecting ? Colors.orange.withOpacity(0.2) : (isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.2))),
                                  blurRadius: 20,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: innerButtonSize,
                                height: innerButtonSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: isConnecting 
                                    ? const Padding(
                                        padding: EdgeInsets.all(30.0),
                                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.orange),
                                      )
                                    : Icon(
                                        CupertinoIcons.power,
                                        size: innerButtonSize * 0.4,
                                        color: isConnected ? Colors.green : (isDark ? Colors.grey.shade400 : Colors.grey),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: screenHeight * 0.04), // Dynamic spacing

                        // Status Text
                        Text(
                          isConnecting 
                              ? (buttonConfig['status_text_connecting'] ?? 'Establishing Connection...') 
                              : (isConnected ? (buttonConfig['status_text_connected'] ?? 'VPN is On') : (buttonConfig['status_text_disconnected'] ?? 'Tap to Connect')),
                          style: TextStyle(
                            color: isConnecting ? Colors.orange : (isConnected ? Colors.green : subTextColor),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Section: Location Selector - Fixed height
                  ValueListenableBuilder<bool>(
                    valueListenable: _userManager.displayLatency,
                    builder: (context, showLatency, child) {
                      // Fixed height based on setting, not connection status
                      final double cardHeight = showLatency ? 190 : 140;
                      
                      return Container(
                        height: cardHeight,
                        margin: EdgeInsets.only(
                          left: 20, 
                          right: 20, 
                          bottom: MediaQuery.of(context).padding.bottom + 20,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isConnected ? (isDark ? Colors.black26 : Colors.grey.shade100) : cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            if (!isConnected)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Selected Location
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: isConnected ? null : () {
                                _openLocationSelection();
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? Colors.grey.withOpacity(0.1) : Colors.grey.shade100,
                                    ),
                                    child: Text(currentFlag, style: const TextStyle(fontSize: 18)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cardConfig['label'] ?? 'Selected Location',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: subTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          currentLocation,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.signal_cellular_alt, size: 18, color: isConnected ? Colors.green : Colors.grey),
                                  const SizedBox(width: 8),
                                  if (!isConnected)
                                    Icon(Icons.arrow_forward_ios, size: 14, color: subTextColor),
                                ],
                              ),
                            ),
                            
                            const Spacer(),

                            if (showLatency) ...[
                              Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, height: 1),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    isConnected ? 'IP 66.93.155.247' : 'IP -.-.-.-',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.arrow_downward, size: 12, color: isConnected ? Colors.green : Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    isConnected ? '1.0KB/s' : '0KB/s',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.arrow_upward, size: 12, color: isConnected ? Colors.purple : Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    isConnected ? '86B/s' : '0B/s',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                            ] else ...[
                              Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, height: 1),
                              const Spacer(),
                            ],
                            
                            // Recent Location - Always visible
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: isConnected ? null : () {
                                setState(() {
                                  currentLocation = 'JP - Tokyo';
                                  currentFlag = '🇯🇵';
                                });
                              },
                              child: Opacity(
                                opacity: isConnected ? 0.5 : 1.0,
                                child: Row(
                                  children: [
                                    const Icon(Icons.history, size: 14, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      cardConfig['recent_label'] ?? 'Recent Location',
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark ? Colors.grey.shade800 : Colors.white,
                                        border: Border.all(color: Colors.grey.shade300, width: 0.5),
                                      ),
                                      child: const Text('🇯🇵', style: TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'JP - Tokyo',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.signal_cellular_alt, size: 14, color: Colors.green.shade400),
                                    if (!isConnected) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_ios, size: 12, color: subTextColor),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ],
              );
            }
          );
        },
      ),
    );
  }
}
