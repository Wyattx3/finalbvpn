import 'package:flutter/foundation.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';

/// Ad Service for managing Rewarded Ads using Appodeal SDK
/// Appodeal handles AdMob + other networks through mediation
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ⚠️ IMPORTANT: Replace with your actual Appodeal App Key from appodeal.com dashboard
  static const String _appodealAppKey = 'YOUR_APPODEAL_APP_KEY';
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  // Callback holders
  Function(double amount, String currency)? _onRewardCallback;
  Function()? _onAdClosedCallback;
  Function()? _onAdFailedCallback;
  
  /// Initialize Appodeal SDK - Call this once at app startup
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('✅ AdService already initialized');
      return;
    }
    
    debugPrint('🎯 Initializing Appodeal SDK...');
    
    // Set test mode for development builds
    Appodeal.setTesting(kDebugMode);
    
    // Enable logging for debug builds
    Appodeal.setLogLevel(kDebugMode ? Appodeal.LogLevelVerbose : Appodeal.LogLevelNone);
    
    // Auto-cache rewarded videos
    Appodeal.setAutoCache(AppodealAdType.RewardedVideo, true);
    
    // Set up rewarded video callbacks
    _setupRewardedCallbacks();
    
    // Initialize with Rewarded Video only
    Appodeal.initialize(
      appKey: _appodealAppKey,
      adTypes: [AppodealAdType.RewardedVideo],
      onInitializationFinished: (errors) {
        if (errors == null || errors.isEmpty) {
          debugPrint('✅ Appodeal SDK initialized successfully');
          _isInitialized = true;
        } else {
          debugPrint('❌ Appodeal initialization errors:');
          for (var error in errors) {
            debugPrint('  - ${error.description}');
          }
          // Still mark as initialized so we can retry loading ads
          _isInitialized = true;
        }
      },
    );
  }
  
  /// Set up rewarded video callbacks
  void _setupRewardedCallbacks() {
    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoLoaded: (isPrecache) {
        debugPrint('📺 Rewarded video loaded (precache: $isPrecache)');
      },
      onRewardedVideoFailedToLoad: () {
        debugPrint('❌ Rewarded video failed to load');
        _onAdFailedCallback?.call();
      },
      onRewardedVideoShown: () {
        debugPrint('📺 Rewarded video shown');
      },
      onRewardedVideoShowFailed: () {
        debugPrint('❌ Rewarded video show failed');
        _onAdFailedCallback?.call();
      },
      onRewardedVideoFinished: (amount, currency) {
        debugPrint('🎁 Reward earned: $amount $currency');
        _onRewardCallback?.call(amount, currency);
      },
      onRewardedVideoClosed: (finished) {
        debugPrint('📺 Rewarded video closed (finished: $finished)');
        _onAdClosedCallback?.call();
      },
      onRewardedVideoExpired: () {
        debugPrint('⚠️ Rewarded video expired');
      },
      onRewardedVideoClicked: () {
        debugPrint('👆 Rewarded video clicked');
      },
    );
  }
  
  /// Check if rewarded ad is loaded and ready to show
  Future<bool> isRewardedAdReady() async {
    if (!_isInitialized) {
      debugPrint('⚠️ AdService not initialized yet');
      return false;
    }
    
    final isLoaded = await Appodeal.isLoaded(AppodealAdType.RewardedVideo);
    debugPrint('📺 Rewarded ad ready: $isLoaded');
    return isLoaded;
  }
  
  /// Show Rewarded Video Ad
  /// Returns true if ad was shown, false if not available
  Future<bool> showRewardedAd({
    required Function(double amount, String currency) onReward,
    Function()? onAdClosed,
    Function()? onAdFailed,
  }) async {
    if (!_isInitialized) {
      debugPrint('⚠️ AdService not initialized - cannot show ad');
      onAdFailed?.call();
      return false;
    }
    
    // Check if ad is loaded
    final isLoaded = await Appodeal.isLoaded(AppodealAdType.RewardedVideo);
    
    if (!isLoaded) {
      debugPrint('⚠️ Rewarded ad not loaded yet');
      onAdFailed?.call();
      return false;
    }
    
    // Store callbacks
    _onRewardCallback = onReward;
    _onAdClosedCallback = onAdClosed;
    _onAdFailedCallback = onAdFailed;
    
    // Show the ad
    debugPrint('📺 Showing rewarded video...');
    final result = await Appodeal.show(AppodealAdType.RewardedVideo);
    
    if (!result) {
      debugPrint('❌ Failed to show rewarded video');
      onAdFailed?.call();
      return false;
    }
    
    return true;
  }
  
  /// Manually trigger ad caching (usually not needed as auto-cache is enabled)
  void cacheRewardedAd() {
    if (_isInitialized) {
      Appodeal.cache(AppodealAdType.RewardedVideo);
      debugPrint('📥 Caching rewarded video...');
    }
  }
  
  /// Get predicted eCPM for rewarded video
  Future<double> getPredictedEcpm() async {
    if (!_isInitialized) return 0.0;
    
    final ecpm = await Appodeal.getPredictedEcpm(AppodealAdType.RewardedVideo);
    debugPrint('💰 Predicted eCPM: $ecpm');
    return ecpm;
  }
}

