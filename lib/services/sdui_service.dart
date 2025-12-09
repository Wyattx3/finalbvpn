import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import '../user_manager.dart';

/// SDUI Service - Fetches UI configurations from Firebase with REAL-TIME updates
class SduiService {
  static final SduiService _instance = SduiService._internal();
  factory SduiService() => _instance;
  SduiService._internal();

  final FirebaseService _firebase = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserManager _userManager = UserManager();
  
  /// Get language code for current language
  String get _currentLangCode {
    final lang = _userManager.currentLanguage.value;
    switch (lang) {
      case 'Myanmar (Zawgyi)':
        return 'my_zawgyi';
      case 'Myanmar (Unicode)':
        return 'my_unicode';
      case 'Japanese':
        return 'ja';
      case 'Chinese':
        return 'zh';
      case 'Thai':
        return 'th';
      default:
        return 'en';
    }
  }
  
  /// Get translated text from SDUI config value
  /// Supports both old format (String) and new format (Map with language codes)
  /// Example new format: {"en": "Settings", "my_zawgyi": "ဆက္တင္", "ja": "設定"}
  String getText(dynamic value, [String? fallback]) {
    if (value == null) return fallback ?? '';
    
    // Old format: just a string
    if (value is String) return value;
    
    // New format: map with language codes
    if (value is Map) {
      final langCode = _currentLangCode;
      // Try exact match first
      if (value.containsKey(langCode)) {
        return value[langCode]?.toString() ?? fallback ?? '';
      }
      // Fallback to English
      if (value.containsKey('en')) {
        return value['en']?.toString() ?? fallback ?? '';
      }
      // Return first available value
      if (value.isNotEmpty) {
        return value.values.first?.toString() ?? fallback ?? '';
      }
    }
    
    return fallback ?? '';
  }
  
  // Cache for screen configs
  final Map<String, Map<String, dynamic>> _cache = {};
  
  // Stream controllers for real-time updates
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};
  
  // Active listeners
  final Map<String, StreamSubscription> _subscriptions = {};

  /// Get screen configuration (one-time fetch)
  Future<Map<String, dynamic>> getScreenConfig(String screenId) async {
    // Check cache first
    if (_cache.containsKey(screenId)) {
      debugPrint('📦 SDUI cache hit: $screenId');
      return _cache[screenId]!;
    }

    // Try Firebase
    try {
      debugPrint('🔄 Fetching SDUI config from Firebase: $screenId');
      final config = await _firebase.getScreenConfig(screenId);
      
      if (config.isNotEmpty) {
        _cache[screenId] = config;
        debugPrint('✅ SDUI config loaded from Firebase: $screenId');
        return config;
      }
    } catch (e) {
      debugPrint('❌ Firebase SDUI error: $e');
    }

    // Fallback to default configs
    debugPrint('⚠️ Using default SDUI config: $screenId');
    final defaultConfig = _getDefaultConfig(screenId);
    _cache[screenId] = defaultConfig;
    return defaultConfig;
  }

  /// Listen to real-time config changes
  Stream<Map<String, dynamic>> watchScreenConfig(String screenId) {
    debugPrint('👀 Starting real-time watch for SDUI: $screenId');
    
    // Return existing stream if available - but emit cached data immediately
    if (_controllers.containsKey(screenId) && !_controllers[screenId]!.isClosed) {
      debugPrint('♻️ Reusing existing stream for: $screenId');
      
      // Emit cached data immediately for new listeners
      if (_cache.containsKey(screenId)) {
        debugPrint('📦 Emitting cached data immediately for: $screenId');
        Future.microtask(() {
          if (!_controllers[screenId]!.isClosed) {
            _controllers[screenId]!.add(_cache[screenId]!);
          }
        });
      }
      
      return _controllers[screenId]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _controllers[screenId] = controller;

    // Start listening to Firestore - snapshots() auto-emits current value + changes
    final subscription = _firestore
        .collection('sdui_configs')
        .doc(screenId)
        .snapshots()
        .listen((snapshot) {
      debugPrint('📡 Firestore snapshot received for: $screenId (exists: ${snapshot.exists})');
      
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final configData = data['config'] ?? data;
        final config = {
          'screen_id': screenId,
          'config': configData,
        };
        
        // Log detailed config for popup
        if (screenId == 'popup_startup') {
          debugPrint('📡 ====== POPUP FIREBASE UPDATE ======');
          debugPrint('📡 title_color: ${configData['title_color']}');
          debugPrint('📡 message_color: ${configData['message_color']}');
          debugPrint('📡 button_color: ${configData['button_color']}');
          debugPrint('📡 button_text_color: ${configData['button_text_color']}');
          debugPrint('📡 is_dismissible: ${configData['is_dismissible']}');
          debugPrint('📡 _lastModified: ${data['_lastModified']}');
          debugPrint('📡 =====================================');
        }
        
        // Update cache
        _cache[screenId] = config;
        
        // Emit new config
        if (!controller.isClosed) {
          controller.add(config);
          debugPrint('🔄 SDUI REAL-TIME UPDATE: $screenId');
        }
      } else {
        // Use default config
        final defaultConfig = _getDefaultConfig(screenId);
        _cache[screenId] = defaultConfig;
        if (!controller.isClosed) {
          controller.add(defaultConfig);
          debugPrint('⚠️ Using default config (no Firestore data): $screenId');
        }
      }
    }, onError: (error) {
      debugPrint('❌ SDUI real-time error for $screenId: $error');
      // Emit cached or default config on error
      final config = _cache[screenId] ?? _getDefaultConfig(screenId);
      if (!controller.isClosed) {
        controller.add(config);
      }
    });

    _subscriptions[screenId] = subscription;

    return controller.stream;
  }

  /// Stop watching a specific config
  void stopWatching(String screenId) {
    _subscriptions[screenId]?.cancel();
    _subscriptions.remove(screenId);
    _controllers[screenId]?.close();
    _controllers.remove(screenId);
    debugPrint('🛑 Stopped watching SDUI: $screenId');
  }

  /// Stop all watchers
  void stopAllWatchers() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    debugPrint('🛑 Stopped all SDUI watchers');
  }

  /// Clear cache (useful when config changes)
  void clearCache() {
    _cache.clear();
    debugPrint('🗑️ SDUI cache cleared');
  }

  /// Dispose service
  void dispose() {
    stopAllWatchers();
    _cache.clear();
  }

  /// Default configurations (fallback)
  Map<String, dynamic> _getDefaultConfig(String screenId) {
    switch (screenId) {
      case 'onboarding':
        return {
          "screen_id": "onboarding",
          "config": {
            "type": "onboarding_flow",
            "pages": [
              {
                "title": "Global Servers",
                "description": "Access content from around the world\nwith our extensive server network.",
                "image": "assets/images/onboarding/Global servers.png"
              },
              {
                "title": "High Speed",
                "description": "Experience blazing fast connection\nspeeds for streaming and gaming.",
                "image": "assets/images/onboarding/High Speed.png"
              },
              {
                "title": "Secure & Private",
                "description": "Your data is protected with\nmilitary-grade encryption.",
                "image": "assets/images/onboarding/Secure & Private.png"
              },
              {
                "title": "Earn Rewards",
                "description": "Watch ads and earn rewards\nthat you can withdraw.",
                "image": "assets/images/onboarding/earn rewards.jpg"
              }
            ],
            "buttons": {
              "skip": "Skip",
              "next": "Next",
              "get_started": "Get Started"
            }
          }
        };

      case 'home':
        return {
          "screen_id": "home",
          "config": {
            "type": "dashboard",
            "app_bar": {
              "title_disconnected": "Not Connected",
              "title_connecting": "Connecting...",
              "title_connected": "Connected"
            },
            "timer_section": {
              "show_timer": true
            },
            "main_button": {
              "status_text_disconnected": "Tap to Connect",
              "status_text_connecting": "Establishing Connection...",
              "status_text_connected": "VPN is On"
            },
            "location_card": {
              "label": "Selected Location",
              "recent_label": "Recent Location",
              "show_latency_toggle": true
            }
          }
        };

      case 'rewards':
        return {
          "screen_id": "rewards",
          "config": {
            "title": "My Rewards",
            "payment_methods": ["KBZ Pay", "Wave Pay"],
            "min_withdraw_mmk": 20000,
            "labels": {
              "balance_label": "Total Points",
              "withdraw_button": "Withdraw Now",
            }
          }
        };

      case 'splash':
        return {
          "screen_id": "splash",
          "config": {
            "app_name": "Suk Fhyoke VPN",
            "tagline": "Secure & Fast",
            "gradient_colors": ["#7E57C2", "#B39DDB"],
            "splash_duration_seconds": 3
          }
        };

      case 'popup_startup':
        return {
          "screen_id": "popup_startup",
          "config": {
            "enabled": false,
            "display_type": "popup",
            "title": "Welcome!",
            "message": "Welcome to Suk Fhyoke VPN",
            "is_dismissible": true
          }
        };

      case 'settings':
        return {
          "screen_id": "settings",
          "config": {
            "title": "Settings",
            "sections": [
              {"title": "General", "items": ["Theme", "Language"]},
              {"title": "VPN", "items": ["Protocol", "Split Tunneling"]},
              {"title": "About", "items": ["About", "Privacy Policy", "Terms of Service"]}
            ]
          }
        };

      case 'earn_money':
        return {
          "screen_id": "earn_money",
          "config": {
            "title": "Earn Money",
            "reward_per_ad": 30,
            "max_ads_per_day": 100
          }
        };

      case 'location_selection':
        return {
          "screen_id": "location_selection",
          "config": {
            "title": "Select Location",
            "show_premium_badge": true
          }
        };

      case 'server_maintenance':
        return {
          "screen_id": "server_maintenance",
          "config": {
            "enabled": false,
            "title": "Under Maintenance",
            "message": "We're currently performing scheduled maintenance.\nPlease check back soon.",
            "estimated_time": "",
            "show_progress": true,
            "background_color": "#1a1a2e",
            "title_color": "#ffffff",
            "message_color": "#b0b0b0",
            "image": ""
          }
        };

      default:
        return {
          "screen_id": screenId,
          "config": {}
        };
    }
  }
}
