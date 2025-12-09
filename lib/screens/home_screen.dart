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
import '../services/localization_service.dart';
import '../utils/message_dialog.dart';
import '../utils/review_utils.dart';
import 'dynamic_popup_screen.dart';
import '../utils/network_utils.dart';
import '../utils/v2ray_config.dart';
import '../widgets/vpn_water_button.dart';
import '../widgets/japanese_wave_background.dart';
import '../widgets/zen_coin_icon.dart';
import '../widgets/gift_box_icon.dart';
import '../widgets/country_flag_icon.dart';
import '../widgets/server_signal_indicator.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
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
  String currentCountryCode = 'US'; // Default country code for flag icon
  int serverTotalConnections = 0; // For signal indicator
  
  late final FlutterV2ray _flutterV2ray;
  
  final UserManager _userManager = UserManager();
  final SduiService _sduiService = SduiService();
  final FirebaseService _firebaseService = FirebaseService();
  final VpnSpeedService _speedService = VpnSpeedService();
  final LocalizationService _l = LocalizationService();
  static const platform = MethodChannel('com.sukfhyoke.vpn/notification');
  // static const vpnPlatform = MethodChannel('com.sukfhyoke.vpn/vpn'); // Replaced by flutter_v2ray
  
  // Current selected server
  Map<String, dynamic>? _selectedServer;
  
  // Last successfully connected server (for Recent Location feature)
  Map<String, dynamic>? _lastConnectedServer;

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
    
    // Initialize V2Ray
    _flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        debugPrint('🔌 V2Ray Status: state=${status.state}, dl=${status.downloadSpeed}B/s, ul=${status.uploadSpeed}B/s, totalDl=${status.download}, totalUl=${status.upload}');
        
        if (mounted) {
          setState(() {
            // Using string comparison as V2RayStatus enum might not be available or state is a String
            isConnected = status.state.toString() == 'CONNECTED';
            isConnecting = status.state.toString() == 'CONNECTING';
          });
          
          // Always update speed service when connected (even if speeds are 0)
          if (isConnected) {
            // Update speed service with real data from plugin
            // flutter_v2ray gives int for speeds (B/s) and cumulative bytes
            _speedService.updateRealTimeStatus(
              status.downloadSpeed, 
              status.uploadSpeed, 
              0, // Ping is measured separately via TCP
              status.upload, 
              status.download
            );
            
            // Update Notification with real stats
            _updateNotificationWithSpeeds(status.downloadSpeed, status.uploadSpeed);
          }
        }
      },
    );
    _flutterV2ray.initializeV2Ray();
    
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
    
    // Recent location is now loaded in _loadFirebaseData after servers are fetched
  }
  
  // Load servers and balance from Firebase
  Future<void> _loadFirebaseData() async {
    try {
      print('🔥 Loading Firebase data...');
      
      // Fetch servers from Firebase
      final servers = await _firebaseService.getServers();
      
      if (mounted && servers.isNotEmpty) {
        setState(() {
          _servers = servers;
        });
        
        // First, try to load recent location
        await _userManager.loadRecentLocation();
        final recentLocation = _userManager.recentLocation.value;
        
        Map<String, dynamic>? serverToSelect;
        
        // If we have a recent location, try to find it in the server list
        if (recentLocation != null && recentLocation['id'] != null) {
          final recentId = recentLocation['id'];
          try {
            serverToSelect = servers.firstWhere(
              (s) => s['id'] == recentId,
              orElse: () => <String, dynamic>{},
            );
            if (serverToSelect.isEmpty) {
              serverToSelect = null; // Not found, will fallback to first
              print('⚠️ Recent server not found in list, using first server');
            } else {
              print('✅ Found recent server: ${serverToSelect['name']}');
            }
          } catch (e) {
            serverToSelect = null;
          }
        }
        
        // Fallback to first server if no recent or not found
        serverToSelect ??= servers.first;
        
        if (mounted) {
          setState(() {
            _selectedServer = serverToSelect;
            currentLocation = '${serverToSelect!['country']} - ${serverToSelect['name']}';
            currentFlag = serverToSelect['flag'] ?? '🌍';
            currentCountryCode = serverToSelect['countryCode'] ?? 'US';
            serverTotalConnections = (serverToSelect['totalConnections'] as num?)?.toInt() ?? 0;
        });
        }
        print('✅ Loaded ${servers.length} servers. Selected: $currentLocation');
        
        // Measure ping for the selected server
        final address = serverToSelect['address'] as String?;
        if (address != null) {
          _speedService.updatePingForServer(address);
        }
      } else {
        // Fallback if no servers
        setState(() {
          currentLocation = 'No servers available';
          currentFlag = '⚠️';
          currentCountryCode = 'XX'; // Invalid code will show fallback
          serverTotalConnections = 0;
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
  static const String _currentAppVersion = '1.0.0';
  
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
          
          // For update popup - ALWAYS force until version matches (user cannot dismiss)
          bool isUpdatePopup = popupType == 'update' && shouldShowForVersion;
          // FORCE update - user MUST update the app, no dismiss allowed
          bool isForceUpdate = isUpdatePopup; // Always force when update is needed
          
          // Show popup if:
          // 1. Enabled AND version needs update (for update popups)
          // 2. OR enabled AND config changed (for other popups)
          bool shouldShow = isEnabled && (
            (isUpdatePopup) || // Always show update popup if version mismatch
            (shouldShowForVersion && configHash != _lastPopupConfigHash)
          );
          
          debugPrint('📢 shouldShow=$shouldShow, isUpdatePopup=$isUpdatePopup, isForceUpdate=$isForceUpdate');
          
          // Auto-disconnect VPN if force update required
          if (isForceUpdate && (isConnected || isConnecting)) {
            debugPrint('📢 Force update required - auto-disconnecting VPN...');
            _autoDisconnectVpn();
          }
          
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
                
                // FORCE UPDATE: Override settings when update is required
                if (isForceUpdate) {
                  popupConfig['is_dismissible'] = false; // Cannot dismiss
                  popupConfig['display_type'] = 'fullscreen'; // Force fullscreen
                  debugPrint('📢 🚨 FORCE UPDATE MODE - User must update!');
                }
                
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
          
          // Auto-disconnect VPN if maintenance mode is enabled
          if (isEnabled && isConnected) {
            debugPrint('🔧 Maintenance mode enabled - auto-disconnecting VPN...');
            _autoDisconnectVpn();
          }
          
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
  
  void _updateNotificationWithSpeeds(int downloadSpeedBytes, int uploadSpeedBytes) {
    if (!isConnected) return;
    
    try {
      final dlStr = _speedService.formatBytes(downloadSpeedBytes) + "/s";
      final ulStr = _speedService.formatBytes(uploadSpeedBytes) + "/s";
      final pingStr = "${_speedService.pingMs.value}ms";
      
      platform.invokeMethod('updateNotificationStats', {
        'download_speed': dlStr,
        'upload_speed': ulStr,
        'ping': pingStr,
      });
    } catch (e) {
      debugPrint('❌ Failed to update notification stats: $e');
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
      
      // Stop speed monitoring and decrement connection count (await to ensure completion)
      await _speedService.stopSpeedMonitoring();
      debugPrint('📱 Speed monitoring stopped, connection count decremented');
      
      // NOTE: Recent location is saved when SWITCHING to a new server, not on disconnect
      
      // Update device status back to 'online' (VPN disconnected but app still open)
      await _firebaseService.updateDeviceStatus('online');
      debugPrint('📱 Device status updated to online (VPN disconnected)');
      
      // Disconnect VPN service
      try {
        await _flutterV2ray.stopV2Ray();
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
        _startVpnConnection();
      } else {
        _showAdDialog();
      }
    }
  }

  void _cancelConnection() async {
    debugPrint('🚫 Connection cancelled by user');
    _connectionCancelled = true;
    await _flutterV2ray.stopV2Ray();
    setState(() {
      isConnecting = false;
    });
  }

  /// Auto-disconnect VPN when ban/maintenance/update required
  Future<void> _autoDisconnectVpn() async {
    if (!isConnected && !isConnecting) return;
    
    debugPrint('🔌 Auto-disconnecting VPN...');
    
    _userManager.stopTimer();
    
    // Stop speed monitoring
    await _speedService.stopSpeedMonitoring();
    
    // Update device status
    await _firebaseService.updateDeviceStatus('online');
    
    // Disconnect VPN
    try {
      await _flutterV2ray.stopV2Ray();
      debugPrint('✅ VPN auto-disconnected');
    } catch (e) {
      debugPrint('❌ Error auto-disconnecting VPN: $e');
    }
    
    if (mounted) {
      setState(() {
        isConnected = false;
        isConnecting = false;
      });
    }
    
    _stopNotification();
  }

  void _startVpnConnection() async {
    _connectionCancelled = false;
    
    // Save the PREVIOUS connected server as recent BEFORE connecting to a new one
    // Only save if: 1) there was a previous connection, 2) it's a different server
    if (_lastConnectedServer != null && 
        _selectedServer != null && 
        _lastConnectedServer!['id'] != _selectedServer!['id']) {
      _userManager.saveRecentLocation(_lastConnectedServer!);
      debugPrint('📍 Saved ${_lastConnectedServer!['name']} as recent (switching to new server)');
    }
    
    // REAL-TIME check server status from Firebase before connecting
    final serverId = _selectedServer?['id'] as String?;
    if (serverId == null) {
      if (mounted) {
        showMessageDialog(
          context,
          message: 'ကျေးဇူးပြု၍ server တစ်ခုကို ရွေးချယ်ပါ',
          type: MessageType.error,
          title: 'Server မရွေးရသေးပါ',
        );
      }
      return;
    }
    
    // Check server status in real-time from Firebase
    final serverStatus = await _firebaseService.getServerStatus(serverId);
    debugPrint('🔍 Server status check: $serverId -> $serverStatus');
    
    if (serverStatus == 'maintenance') {
      if (mounted) {
        showMessageDialog(
          context,
          message: 'ဤ server သည် maintenance လုပ်နေပါသည်။ တခြား server ကို ရွေးချယ်ပါ။',
          type: MessageType.warning,
          title: 'Server Maintenance',
        );
      }
      return;
    }
    if (serverStatus == 'offline') {
      if (mounted) {
        showMessageDialog(
          context,
          message: 'ဤ server သည် offline ဖြစ်နေပါသည်။ တခြား server ကို ရွေးချယ်ပါ။',
          type: MessageType.error,
          title: 'Server Offline',
        );
      }
      return;
    }
    
    setState(() {
      isConnecting = true;
    });
    
    // Get port based on selected protocol
    final protocolName = _userManager.getProtocolName();
    final networkType = _userManager.getNetworkForProtocol();
    // Default ports: 443 (WS), 8443 (TCP), 4434 (QUIC)
    int port = 443;
    if (networkType == 'tcp') port = 8443;
    if (networkType == 'quic') port = 4434;
    
    debugPrint('🔌 Connecting with protocol: $protocolName on port $port');
    
    // Request VPN permission and connect
    try {
      if (await _flutterV2ray.requestPermission()) {
        final serverAddress = _selectedServer?['address'] as String? ?? '';
        final uuid = _selectedServer?['uuid'] as String? ?? '';
        final path = _selectedServer?['path'] as String? ?? '/';
        final useTls = _selectedServer?['tls'] as bool? ?? true;
        final alterId = (_selectedServer?['alterId'] as num?)?.toInt() ?? 0;
        final security = _selectedServer?['security'] as String? ?? 'auto';
        
        debugPrint('🔌 Connecting to V2Ray: $serverAddress:$port');
        debugPrint('🔌 Protocol: $networkType, TLS: $useTls, Path: $path');
        debugPrint('🔌 UUID: ${uuid.substring(0, 8)}..., Security: $security');
        
        // Generate Config
        final config = V2RayConfig.generateConfig(
          serverAddress: serverAddress,
          serverPort: port,
          uuid: uuid,
          alterId: alterId,
          security: security,
          network: networkType,
          path: path,
          tls: useTls,
          remark: _selectedServer?['name'] ?? 'Suk Fhyoke',
        );
        
        // Get blocked apps for split tunneling
        final blockedApps = _userManager.getBlockedApps();
        if (blockedApps != null && blockedApps.isNotEmpty) {
          debugPrint('🔌 Split tunneling: blocking ${blockedApps.length} apps from VPN');
        }
        
        // Start V2Ray
        await _flutterV2ray.startV2Ray(
          remark: _selectedServer?['name'] ?? 'Suk Fhyoke',
          config: config,
          blockedApps: blockedApps,
        );
        
        // Note: isConnected state will be updated by onStatusChanged listener
        
        // Measure ping to server
        if (serverAddress.isNotEmpty) {
          await _speedService.updatePingForServer(serverAddress);
        }
        
        if (mounted && !_connectionCancelled) {
          _userManager.startTimer();
          _startNotification();
          
          // Track this as the last connected server (for Recent Location feature)
          _lastConnectedServer = _selectedServer;
          debugPrint('📍 Tracking ${_selectedServer?['name']} as last connected server');
          
          // Update device status to 'vpn_connected' (online with VPN)
          await _firebaseService.updateDeviceStatus('vpn_connected');
          debugPrint('📱 Device status updated to vpn_connected');
          
          // Start speed monitoring (Firebase bandwidth tracking)
          final deviceId = await _firebaseService.getDeviceId();
          final serverId = _selectedServer?['id'] as String? ?? 'unknown';
          _speedService.startSpeedMonitoring(serverId, deviceId, serverAddress: serverAddress);
          
          debugPrint('✅ Connected via $protocolName');
        }
      } else {
        // Permission denied
        if (mounted) {
          setState(() {
            isConnecting = false;
          });
          showMessageDialog(
            context,
            message: 'VPN permission required',
            type: MessageType.warning,
            title: 'Connection Failed',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ VPN Error: $e');
      if (mounted) {
        setState(() {
          isConnecting = false;
        });
        showMessageDialog(
          context,
          message: 'Failed to connect: $e',
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
                'Watch a short ad to get $timeBonusText of VPN time and earn $rewardPerAd Points.',
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
          message: '+$timeBonusText Added, +$rewardPerAd Points Earned',
          type: MessageType.success,
          title: 'Reward Earned!',
          onOkPressed: () {
            // Add reward AFTER user confirms
            _userManager.watchAdReward();
            _startVpnConnection();
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
      final server = result['server'] as Map<String, dynamic>?;
      setState(() {
        currentLocation = result['location'];
        currentFlag = result['flag'] ?? '🏳️';
        currentCountryCode = result['countryCode'] ?? server?['countryCode'] ?? 'US';
        serverTotalConnections = (server?['totalConnections'] as num?)?.toInt() ?? 0;
        _selectedServer = server;
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

    return ValueListenableBuilder<String>(
      valueListenable: _userManager.currentLanguage,
      builder: (context, currentLang, _) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // Always dark icons
          statusBarBrightness: Brightness.light,    // For iOS
        ),
        child: Stack(
          children: [
          if (!isDark) // Only show waves in light mode or make them subtle in dark mode
             const Positioned.fill(child: JapaneseWaveBackground()),
             
          Column(
            children: [
              // Add top padding to account for status bar since we are using Stack
              SizedBox(height: MediaQuery.of(context).padding.top),
              
              AppBar(
                backgroundColor: Colors.transparent, // Make transparent to see waves
        elevation: 0,
                leading: GestureDetector(
                  onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EarnMoneyScreen()),
            );
          },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: ZenCoinIcon(size: 40),
                  ),
        ),
        title: ValueListenableBuilder<int>(
          valueListenable: _userManager.splitTunnelingMode,
          builder: (context, splitMode, child) {
            final titleColor = isConnecting ? Colors.orange : (isConnected ? Colors.green : (isDark ? Colors.white : Colors.black));
            
                    String titleText = _sduiService.getText(appBarConfig['title_disconnected'], 'Not Connected');
                    if (isConnecting) titleText = _sduiService.getText(appBarConfig['title_connecting'], 'Connecting...');
                    if (isConnected) titleText = _sduiService.getText(appBarConfig['title_connected'], 'Connected');

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
                  GestureDetector(
                    onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RewardsScreen()),
              );
            },
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: GiftBoxIcon(size: 40),
                    ),
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
              Expanded(
                child: LayoutBuilder(
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
                                    VPNWaterButton(
                                      size: buttonSize,
                                      state: isConnecting 
                                          ? VPNState.connecting 
                                          : (isConnected ? VPNState.connected : VPNState.idle),
                            onTap: _toggleConnection,
                        ),
                        
                          const SizedBox(height: 20), // Fixed spacing

                          // Status Text
                          Text(
                            isConnecting 
                                          ? _sduiService.getText(buttonConfig['status_text_connecting'], 'Connecting...') 
                                          : (isConnected ? _sduiService.getText(buttonConfig['status_text_connected'], 'VPN is On') : _sduiService.getText(buttonConfig['status_text_disconnected'], 'Tap to Connect')),
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
                                            // Country Flag Icon (instead of emoji)
                                            CountryFlagIcon(
                                              countryCode: currentCountryCode,
                                              size: 36,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                                    _sduiService.getText(cardConfig['label'], 'Selected Location'),
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
                                            // Server Signal Indicator (colored bars based on load)
                                            ServerSignalIndicator(
                                              totalConnections: serverTotalConnections,
                                              isConnected: isConnected,
                                              size: 18,
                                            ),
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
                                              const SizedBox(width: 8),
                                              // Server Load
                                              ValueListenableBuilder<String>(
                                                valueListenable: _speedService.serverLoadStatus,
                                                builder: (context, load, child) {
                                                  Color loadColor = Colors.green;
                                                  if (load == 'Medium') loadColor = Colors.orange;
                                                  if (load == 'High') loadColor = Colors.red;
                                                  
                                                  return Row(
                                                    children: [
                                                      Icon(Icons.dns, size: 12, color: isConnected ? loadColor : Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Load: $load',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: textColor.withOpacity(0.7),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
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
                                      ValueListenableBuilder<Map<String, dynamic>?>(
                                        valueListenable: _userManager.recentLocation,
                                        builder: (context, recent, child) {
                                          final bool hasRecent = recent != null;
                                          final String flag = hasRecent ? (recent['flag'] ?? '🌍') : '🏳️';
                                          final String countryCode = hasRecent ? (recent['countryCode'] ?? 'US') : 'XX';
                                          final String name = hasRecent ? (recent['name'] ?? 'Unknown') : 'No Recent Location';
                                          final int recentConnections = hasRecent ? ((recent['totalConnections'] as num?)?.toInt() ?? 0) : 0;
                                          
                                          return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                                            onTap: (isConnected || !hasRecent) ? null : () {
                                              // Quick connect to recent location logic
                                              // We need to find this server in our _servers list to select it properly
                                              // Or we can rely on the saved 'server_data' if we trust it hasn't changed
                                              
                                              final savedServerData = recent['server_data'];
                                              
                                              // Logic: Try to find server by ID in current _servers list first (to get updated config)
                                              // If not found, fallback to savedServerData
                                              // If neither exists, show error
                                              
                                              Map<String, dynamic>? targetServer = savedServerData;
                                              
                                              // Try to find updated server details from fetched list
                                              if (recent['id'] != null && _servers.isNotEmpty) {
                                                try {
                                                  final updatedServer = _servers.firstWhere(
                                                    (s) => s['id'] == recent['id'], 
                                                    orElse: () => <String, dynamic>{}
                                                  );
                                                  if (updatedServer.isNotEmpty) {
                                                    targetServer = updatedServer;
                                                  }
                                                } catch (e) {
                                                  // Ignore find error
                                                }
                                              }

                                              if (targetServer != null) {
                                setState(() {
                                                  _selectedServer = targetServer;
                                                  currentLocation = recent['name'];
                                                  currentFlag = recent['flag'];
                                });
                                                // Trigger ping check for this new selection
                                                final address = targetServer!['address'];
                                                if (address != null) {
                                                  _speedService.updatePingForServer(address);
                                                }
                                              } else {
                                                showMessageDialog(
                                                  context,
                                                  message: 'Server not found or configuration changed.',
                                                  type: MessageType.error,
                                                  title: 'Connection Error',
                                                );
                                              }
                              },
                              child: Opacity(
                                              opacity: (isConnected || !hasRecent) ? 0.5 : 1.0,
                                child: Row(
                                  children: [
                                    const Icon(Icons.history, size: 14, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                                    _sduiService.getText(cardConfig['recent_label'], 'Recent Location'),
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                                  // Country Flag Icon (small)
                                                  CountryFlagIconSmall(
                                                    countryCode: countryCode,
                                                    size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                                  // Server Signal Indicator (colored bars)
                                                  ServerSignalIndicator(
                                                    totalConnections: recentConnections,
                                                    size: 14,
                                                  ),
                                                  if (!isConnected && hasRecent) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_ios, size: 12, color: subTextColor),
                                    ],
                                  ],
                                ),
                              ),
                                          );
                                        },
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
              ),
            ],
          ),
        ],
      ),
    ),
    );
      }  // Close ValueListenableBuilder builder
    );  // Close ValueListenableBuilder
  }
}
