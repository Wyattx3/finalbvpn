import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'settings_screen.dart';
import 'location_selection_screen.dart';
import 'rewards_screen.dart';
import 'earn_money_screen.dart';
import 'server_maintenance_screen.dart';
import 'network_error_screen.dart';
import '../user_manager.dart';
import '../services/sdui_service.dart';
import '../services/firebase_service.dart';
import '../services/vpn_speed_service.dart';
import '../utils/message_dialog.dart';
import '../utils/review_utils.dart';
import 'dynamic_popup_screen.dart';
import '../utils/network_utils.dart';
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
  bool _connectionCancelled = false;
  String currentLocation = 'Loading...';
  String currentFlag = '🌍';
  
  final UserManager _userManager = UserManager();
  final SduiService _sduiService = SduiService();
  final FirebaseService _firebaseService = FirebaseService();
  final VpnSpeedService _speedService = VpnSpeedService();
  static const platform = MethodChannel('com.example.vpn_app/notification');
  static const vpnPlatform = MethodChannel('com.example.vpn_app/vpn');
  
  // Current selected server
  Map<String, dynamic>? _selectedServer;

  // SDUI Config
  Map<String, dynamic> _config = {};
  bool _isLoading = true;
  StreamSubscription<Map<String, dynamic>>? _sduiSubscription;
  
  // Earn Money Config (for ad dialog)
  Map<String, dynamic> _earnMoneyConfig = {};
  StreamSubscription<Map<String, dynamic>>? _earnMoneySubscription;
  
  // Server Maintenance Config
  Map<String, dynamic> _maintenanceConfig = {};
  bool _isMaintenanceMode = false;
  StreamSubscription<Map<String, dynamic>>? _maintenanceSubscription;
  
  // Network Error State
  bool _hasNetworkError = false;
  String _networkErrorMessage = '';
  
  // Server data from Firebase
  List<Map<String, dynamic>> _servers = [];

  @override
  void initState() {
    super.initState();
    
    // Load Firebase data
    _loadFirebaseData();
    
    // Load SDUI Config
    _loadServerConfig();
    
    // Check for Server Maintenance Mode
    _startMaintenanceListener();
    
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
  
  // Load servers and balance from Firebase
  Future<void> _loadFirebaseData() async {
    try {
      print('🔥 Loading Firebase data...');
      
      // Fetch servers from Firebase
      final servers = await _firebaseService.getServers();
      
      if (mounted && servers.isNotEmpty) {
        final firstServer = servers.first;
        setState(() {
          _servers = servers;
          _selectedServer = firstServer;
          currentLocation = '${firstServer['country']} - ${firstServer['name']}';
          currentFlag = firstServer['flag'] ?? '🌍';
        });
        print('✅ Loaded ${servers.length} servers. Default: $currentLocation');
        
        // Measure ping for the selected server
        final address = firstServer['address'] as String?;
        if (address != null) {
          _speedService.updatePingForServer(address);
        }
      } else {
        // Fallback if no servers
        setState(() {
          currentLocation = 'No servers available';
          currentFlag = '⚠️';
        });
        print('⚠️ No servers found in Firebase');
      }
      
      // Refresh balance
      await _userManager.refreshBalance();
      print('💰 Balance: ${_userManager.balancePoints.value} points');
      
    } catch (e) {
      print('❌ Firebase data error: $e');
      if (mounted) {
        setState(() {
          currentLocation = 'Connection error';
          currentFlag = '❌';
        });
      }
    }
  }

  Future<void> _checkReviewRequest() async {
    // Uncomment the line below to RESET for testing purposes (will set install time to 49h ago)
    await ReviewUtils.debugResetForTesting(); 
    
    if (mounted) {
      await ReviewUtils.checkAndRequestReview(context);
    }
  }

  StreamSubscription? _popupSubscription;
  String _lastPopupConfigHash = '';
  
  // Current app version (should match pubspec.yaml)
  static const String _currentAppVersion = '1.0.1';
  
  // Compare version strings (returns true if required > current)
  bool _isVersionNewer(String required, String current) {
    if (required.isEmpty) return false;
    
    final requiredParts = required.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    // Pad with zeros
    while (requiredParts.length < 3) requiredParts.add(0);
    while (currentParts.length < 3) currentParts.add(0);
    
    for (int i = 0; i < 3; i++) {
      if (requiredParts[i] > currentParts[i]) return true;
      if (requiredParts[i] < currentParts[i]) return false;
    }
    return false; // Equal versions
  }

  void _startPopupListener() {
    debugPrint('📢 Starting popup listener...');
    _popupSubscription?.cancel();
    _popupSubscription = _sduiService.watchScreenConfig('popup_startup').listen(
      (response) {
        debugPrint('📢 Popup response received: ${response.keys}');
        if (mounted) {
          final config = response['config'] as Map<String, dynamic>? ?? {};
          final bool isEnabled = config['enabled'] == true;
          final String popupType = config['popup_type'] as String? ?? 'announcement';
          final String requiredVersion = config['required_app_version'] as String? ?? '';
          
          // For update popups, check version
          bool shouldShowForVersion = true;
          if (popupType == 'update' && requiredVersion.isNotEmpty) {
            shouldShowForVersion = _isVersionNewer(requiredVersion, _currentAppVersion);
            debugPrint('📢 Update popup - required: $requiredVersion, current: $_currentAppVersion, needs update: $shouldShowForVersion');
          }
          
          // Create a hash of the config to detect changes (include ALL fields)
          final buttons = config['buttons']?.toString() ?? '';
          final configHash = [
            config['enabled'],
            config['title'],
            config['message'],
            config['image'],
            config['display_type'],
            config['title_color'],
            config['message_color'],
            config['button_color'],
            config['button_text_color'],
            config['is_dismissible'],
            config['popup_type'],
            config['required_app_version'],
            buttons,
          ].join('_');
          
          debugPrint('📢 ======= POPUP CONFIG UPDATE =======');
          debugPrint('📢 enabled: $isEnabled');
          debugPrint('📢 popup_type: $popupType');
          debugPrint('📢 required_version: $requiredVersion');
          debugPrint('📢 current_version: $_currentAppVersion');
          debugPrint('📢 display_type: ${config['display_type']}');
          debugPrint('📢 is_dismissible: ${config['is_dismissible']}');
          debugPrint('📢 hash: $configHash');
          debugPrint('📢 lastHash: $_lastPopupConfigHash');
          debugPrint('📢 =====================================');
          
          // For update popup - always show until version matches (regardless of dismiss setting)
          bool isUpdatePopup = popupType == 'update' && shouldShowForVersion;
          bool isForceUpdate = isUpdatePopup && config['is_dismissible'] == false;
          
          // Show popup if:
          // 1. Enabled AND version needs update (for update popups)
          // 2. OR enabled AND config changed (for other popups)
          bool shouldShow = isEnabled && (
            (isUpdatePopup) || // Always show update popup if version mismatch
            (shouldShowForVersion && configHash != _lastPopupConfigHash)
          );
          
          debugPrint('📢 shouldShow=$shouldShow, isUpdatePopup=$isUpdatePopup, isForceUpdate=$isForceUpdate');
          
          if (shouldShow) {
            // For update popups, never update hash so it keeps showing
            if (!isUpdatePopup) {
              _lastPopupConfigHash = configHash;
            }
            debugPrint('📢 ✅ Showing popup now! ${isForceUpdate ? "(FORCE UPDATE - can\'t dismiss)" : isUpdatePopup ? "(UPDATE REQUIRED)" : "(new config)"}');
            
            // Close ALL dialogs first before showing new one
            Navigator.of(context).popUntil((route) => route.isFirst);
            
            // Show new popup after a short delay to ensure old one is closed
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) {
                // Add version check flag to config so _handleAction knows if update is really needed
                final popupConfig = Map<String, dynamic>.from(config);
                popupConfig['_needs_update'] = shouldShowForVersion;
                showDynamicPopup(context, popupConfig);
              }
            });
          } else if (!isEnabled) {
            // Reset hash when disabled so it shows again when re-enabled
            _lastPopupConfigHash = '';
            // Also close any open popup when disabled
            Navigator.of(context).popUntil((route) => route.isFirst);
            debugPrint('📢 ❌ Popup disabled, hash reset');
          } else if (!shouldShowForVersion && popupType == 'update') {
            _lastPopupConfigHash = ''; // Reset hash so it shows again if version changes
            // Close any existing popup since app is now up to date
            Navigator.of(context).popUntil((route) => route.isFirst);
            debugPrint('📢 ✅ App is up to date (v$_currentAppVersion >= v$requiredVersion), closing any update popup');
          } else {
            debugPrint('📢 ⏭️ Skipped: same config or not enabled');
          }
        }
      },
      onError: (e) => debugPrint("📢 Popup listener error: $e"),
    );
  }

  Future<void> _checkStartupPopup() async {
    // Start real-time listener for popup updates
    _startPopupListener();
  }

  void _loadServerConfig() {
    debugPrint('🏠 Home: Starting SDUI real-time listener...');
    
    // Timeout fallback - if SDUI doesn't load in 3 seconds, show default UI
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        debugPrint('⚠️ Home: SDUI timeout - showing default UI');
        setState(() {
          _isLoading = false;
        });
      }
    });
    
    // Use real-time listener for SDUI updates
    _sduiSubscription = _sduiService.watchScreenConfig('home').listen(
      (response) {
        debugPrint('🏠 Home: Received SDUI update! Config keys: ${response.keys}');
        if (mounted) {
          final newConfig = response['config'] ?? {};
          
          // Check if show_timer changed and update notification
          final oldTimerConfig = _config['timer_section'] ?? {};
          final newTimerConfig = newConfig['timer_section'] ?? {};
          final bool oldShowTimer = oldTimerConfig['show_timer'] ?? true;
          final bool newShowTimer = newTimerConfig['show_timer'] ?? true;
          
          if (oldShowTimer != newShowTimer) {
            debugPrint('🏠 Home: show_timer changed from $oldShowTimer to $newShowTimer');
            _updateNotificationShowTimer(newShowTimer);
          }
          
          debugPrint('🏠 Home: Updating UI with new config...');
          setState(() {
            _config = newConfig;
            _isLoading = false;
          });
          debugPrint('✅ Home: UI updated with real-time SDUI config!');
        }
      },
      onError: (e) {
        debugPrint("❌ Home SDUI Error: $e");
        if (mounted) setState(() => _isLoading = false);
      },
    );
    
    // Also load earn_money config for ad dialog text
    _earnMoneySubscription = _sduiService.watchScreenConfig('earn_money').listen(
      (response) {
        debugPrint('🏠 Home: Received earn_money config for ad dialog');
        if (mounted) {
          final config = response['config'] ?? {};
          setState(() {
            _earnMoneyConfig = config;
          });
          debugPrint('✅ Home: earn_money config updated - reward: ${config['reward_per_ad']}, time_bonus: ${config['time_bonus_seconds']}');
        }
      },
      onError: (e) {
        debugPrint("❌ Home earn_money SDUI Error: $e");
      },
    );
  }

  void _startMaintenanceListener() {
    debugPrint('🔧 Home: Starting server maintenance listener...');
    
    _maintenanceSubscription = _sduiService.watchScreenConfig('server_maintenance').listen(
      (response) {
        debugPrint('🔧 Home: Received maintenance config update');
        if (mounted) {
          final config = response['config'] ?? {};
          final bool isEnabled = config['enabled'] == true;
          
          debugPrint('🔧 Maintenance mode: $isEnabled');
          
          setState(() {
            _maintenanceConfig = config;
            _isMaintenanceMode = isEnabled;
          });
        }
      },
      onError: (e) {
        debugPrint("❌ Maintenance SDUI Error: $e");
        // On error, show network error screen
        if (mounted) {
          setState(() {
            _hasNetworkError = true;
            _networkErrorMessage = 'Unable to connect to server.\nPlease check your internet connection.';
          });
        }
      },
    );
  }

  void _retryConnection() {
    debugPrint('🔄 Retrying connection...');
    setState(() {
      _hasNetworkError = false;
      _networkErrorMessage = '';
      _isLoading = true;
    });
    
    // Restart all listeners
    _loadServerConfig();
    _startMaintenanceListener();
    _checkStartupPopup();
    _loadFirebaseData();
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
    _sduiSubscription?.cancel();
    _earnMoneySubscription?.cancel();
    _popupSubscription?.cancel();
    _maintenanceSubscription?.cancel();
    _userManager.stopTimer();
    _speedService.stopSpeedMonitoring();
    _stopNotification();
    super.dispose();
  }
  
  Future<void> _startNotification() async {
    // Get show_timer from SDUI config
    final timerConfig = _config['timer_section'] ?? {};
    final bool showTimer = timerConfig['show_timer'] ?? true;
    
    try {
      await platform.invokeMethod('startNotification', {
        'location': currentLocation,
        'flag': currentFlag,
        'remaining_seconds': _userManager.remainingSeconds.value,
        'show_timer': showTimer,
      });
      
      // Listen to remaining seconds changes and update notification
      _userManager.remainingSeconds.addListener(_updateNotificationTime);
    } on PlatformException catch (e) {
      debugPrint("Failed to start notification: '${e.message}'.");
    }
  }
  
  void _updateNotificationShowTimer(bool showTimer) {
    if (isConnected) {
      try {
        platform.invokeMethod('updateShowTimer', {
          'show_timer': showTimer,
        });
      } catch (e) {
        debugPrint("Failed to update show timer: $e");
      }
    }
  }
  
  void _updateNotificationTime() {
    if (isConnected) {
      try {
        platform.invokeMethod('updateNotificationTime', {
          'remaining_seconds': _userManager.remainingSeconds.value,
        });
      } catch (e) {
        // Silently fail - notification update is not critical
      }
    }
  }

  Future<void> _stopNotification() async {
    try {
      // Remove listener when stopping notification
      _userManager.remainingSeconds.removeListener(_updateNotificationTime);
      await platform.invokeMethod('stopNotification');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop notification: '${e.message}'.");
    }
  }

  void _toggleConnection() async {
    // If connecting, cancel the connection
    if (isConnecting) {
      _cancelConnection();
      return;
    }

    if (isConnected) {
      _userManager.stopTimer();
      _speedService.stopSpeedMonitoring(); // Stop speed monitoring
      
      // Disconnect VPN service
      try {
        await vpnPlatform.invokeMethod('disconnectVpn');
        debugPrint('📱 VPN disconnected');
      } catch (e) {
        debugPrint('❌ Error disconnecting VPN: $e');
      }
      
      setState(() {
        isConnected = false;
      });
      _stopNotification();
    } else {
      // Check network connection before connecting
      final hasConnection = await NetworkUtils.hasInternetConnection();
      if (!hasConnection) {
        if (mounted) {
          NetworkUtils.showNetworkErrorDialog(context, onRetry: _toggleConnection);
        }
        return;
      }
      
      if (_userManager.remainingSeconds.value > 0) {
        _simulateConnection();
      } else {
        _showAdDialog();
      }
    }
  }

  void _cancelConnection() {
    debugPrint('🚫 Connection cancelled by user');
    _connectionCancelled = true;
    setState(() {
      isConnecting = false;
    });
  }

  void _simulateConnection() async {
    _connectionCancelled = false;
    setState(() {
      isConnecting = true;
    });
    
    // Get port based on selected protocol
    final port = _userManager.getPortForProtocol();
    final protocolName = _userManager.getProtocolName();
    final networkType = _userManager.getNetworkForProtocol();
    debugPrint('🔌 Connecting with protocol: $protocolName on port $port');
    
    // Request VPN permission and connect
    try {
      final serverAddress = _selectedServer?['address'] as String? ?? '';
      final uuid = _selectedServer?['uuid'] as String? ?? '';
      
      // Call native VPN connection
      final result = await vpnPlatform.invokeMethod('connectVpn', {
        'server_address': serverAddress,
        'server_port': port,
        'protocol': networkType,
        'uuid': uuid,
      });
      
      debugPrint('📱 VPN connect result: $result');
      
      if (result['success'] == true) {
        // Measure ping to server
        if (serverAddress.isNotEmpty) {
          await _speedService.updatePingForServer(serverAddress);
        }
        
        if (mounted && !_connectionCancelled) {
          setState(() {
            isConnecting = false;
            isConnected = true;
          });
          _userManager.startTimer();
          _startNotification();
          
          // Start speed monitoring
          final deviceId = await _firebaseService.getDeviceId();
          final serverId = _selectedServer?['id'] as String? ?? 'unknown';
          _speedService.startSpeedMonitoring(serverId, deviceId);
          
          debugPrint('✅ Connected via $protocolName');
        }
      } else {
        // Permission denied or connection failed
        if (mounted) {
          setState(() {
            isConnecting = false;
          });
          showMessageDialog(
            context,
            message: result['error'] ?? 'VPN permission required',
            type: MessageType.warning,
            title: 'Connection Failed',
          );
        }
      }
    } on PlatformException catch (e) {
      debugPrint('❌ VPN Platform error: ${e.message}');
      if (mounted) {
        setState(() {
          isConnecting = false;
        });
        showMessageDialog(
          context,
          message: 'Failed to connect: ${e.message}',
          type: MessageType.error,
          title: 'Error',
        );
      }
    }
  }

  void _showAdDialog() {
    // Get values from SDUI config (cast to int to handle Firestore num/double)
    final int timeBonusSeconds = (_earnMoneyConfig['time_bonus_seconds'] as num?)?.toInt() ?? 7200;
    final int rewardPerAd = (_earnMoneyConfig['reward_per_ad'] as num?)?.toInt() ?? 30;
    
    // Format time bonus for display
    String timeBonusText;
    if (timeBonusSeconds >= 3600) {
      final hours = timeBonusSeconds / 3600;
      timeBonusText = hours == hours.toInt() ? '${hours.toInt()} hours' : '${hours.toStringAsFixed(1)} hours';
    } else {
      final minutes = timeBonusSeconds ~/ 60;
      timeBonusText = '$minutes minutes';
    }
    
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
              Text(
                'Watch a short ad to get $timeBonusText of VPN time and earn $rewardPerAd MMK.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
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

  void _simulateAdWatch() async {
    // Check network connection before watching ad
    final hasConnection = await NetworkUtils.hasInternetConnection();
    if (!hasConnection) {
      if (mounted) {
        NetworkUtils.showNetworkErrorDialog(context, onRetry: _simulateAdWatch);
      }
      return;
    }
    
    // Get values from SDUI config (cast to int to handle Firestore num/double)
    final int timeBonusSeconds = (_earnMoneyConfig['time_bonus_seconds'] as num?)?.toInt() ?? 7200;
    final int rewardPerAd = (_earnMoneyConfig['reward_per_ad'] as num?)?.toInt() ?? 30;
    
    // Format time bonus for success message
    String timeBonusText;
    if (timeBonusSeconds >= 3600) {
      final hours = timeBonusSeconds / 3600;
      timeBonusText = hours == hours.toInt() ? '${hours.toInt()} Hours' : '${hours.toStringAsFixed(1)} Hours';
    } else {
      final minutes = timeBonusSeconds ~/ 60;
      timeBonusText = '$minutes Minutes';
    }
    
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
        
        // Show reward dialog - only add points when user taps OK
        showMessageDialog(
          context,
          message: '+$timeBonusText Added, +$rewardPerAd MMK Earned',
          type: MessageType.success,
          title: 'Reward Earned!',
          onOkPressed: () {
            // Add reward AFTER user confirms
            _userManager.watchAdReward();
            _simulateConnection();
          },
        );
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
        _selectedServer = result['server'] as Map<String, dynamic>?;
      });
      
      // Update ping for new server
      final address = _selectedServer?['address'] as String?;
      if (address != null) {
        _speedService.updatePingForServer(address);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show network error screen if connection failed
    if (_hasNetworkError) {
      return NetworkErrorScreen(
        errorMessage: _networkErrorMessage,
        onRetry: _retryConnection,
      );
    }
    
    // Show maintenance screen if server is under maintenance
    if (_isMaintenanceMode) {
      return ServerMaintenanceScreen(config: _maintenanceConfig);
    }
    
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
    final timerConfig = _config['timer_section'] ?? {};
    final bool showTimer = timerConfig['show_timer'] ?? true;

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
              // Format time from the builder's remainingSeconds value
              int h = remainingSeconds ~/ 3600;
              int m = (remainingSeconds % 3600) ~/ 60;
              int s = remainingSeconds % 60;
              String formattedTime = "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
              
              return Column(
                children: [
                  // Top Section: Timer (Flexible space) - Controlled by SDUI
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: (showTimer && remainingSeconds > 0)
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
                                  formattedTime,
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
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
                        
                          const SizedBox(height: 20), // Fixed spacing

                          // Status Text
                          Text(
                            isConnecting 
                                ? (buttonConfig['status_text_connecting'] ?? 'Connecting...') 
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
                              ValueListenableBuilder<int>(
                                valueListenable: _speedService.pingMs,
                                builder: (context, ping, child) {
                                  return ValueListenableBuilder<double>(
                                    valueListenable: _speedService.downloadSpeed,
                                    builder: (context, download, child) {
                                      return ValueListenableBuilder<double>(
                                        valueListenable: _speedService.uploadSpeed,
                                        builder: (context, upload, child) {
                                          return Row(
                                            children: [
                                              // Ping display
                                              Icon(Icons.network_ping, size: 12, color: isConnected ? Colors.blue : Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${ping > 0 ? ping : '-'}ms',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: ping < 100 ? Colors.green : (ping < 200 ? Colors.orange : Colors.red),
                                                ),
                                              ),
                                              const Spacer(),
                                              // Download speed
                                              Icon(Icons.arrow_downward, size: 12, color: isConnected ? Colors.green : Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(
                                                isConnected ? _speedService.downloadSpeedString : '0 B/s',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: textColor.withOpacity(0.7),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Upload speed
                                              Icon(Icons.arrow_upward, size: 12, color: isConnected ? Colors.purple : Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(
                                                isConnected ? _speedService.uploadSpeedString : '0 B/s',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: textColor.withOpacity(0.7),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
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
