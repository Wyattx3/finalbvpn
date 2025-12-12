import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/banned_screen.dart';
import 'theme_notifier.dart';
import 'services/firebase_service.dart';
import 'services/ad_service.dart';
import 'user_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('=== APP STARTING ===');
  
  // Enable edge-to-edge but with colored system bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  // Initialize Firebase ONLY (required for app to work)
  // Device registration and other heavy operations happen in SplashScreen
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print('=== FIREBASE CORE INIT OK ===');
  } catch (e) {
    print('=== FIREBASE ERROR: $e ===');
  }
  
  print('=== STARTING APP UI ===');
  
  // Run app IMMEDIATELY - don't block with heavy initialization
  // SplashScreen will handle device registration, servers loading, and ads SDK
  runApp(const VPNApp());
}

class VPNApp extends StatefulWidget {
  const VPNApp({super.key});

  // Light Theme Colors - Soft & Clean
  static const Color lightPrimaryPurple = Color(0xFF7E57C2);
  static const Color lightSecondaryPurple = Color(0xFFB39DDB);
  static const Color lightBackground = Color(0xFFFAFAFC); // Very subtle gray-white
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardColor = Color(0xFFFFFFFF);

  // Dark Theme Colors - Deep Purple & Dark
  static const Color darkPrimaryPurple = Color(0xFFB388FF);
  static const Color darkSecondaryPurple = Color(0xFF7C4DFF);
  static const Color darkBackground = Color(0xFF1A1625);
  static const Color darkSurface = Color(0xFF2D2640);
  static const Color darkCardColor = Color(0xFF352F44);

  @override
  State<VPNApp> createState() => _VPNAppState();
}

class _VPNAppState extends State<VPNApp> with WidgetsBindingObserver {
  final FirebaseService _firebaseService = FirebaseService();
  final UserManager _userManager = UserManager();
  Timer? _heartbeatTimer;
  
  // Ban status
  final ValueNotifier<bool> _isBanned = ValueNotifier(false);
  StreamSubscription<bool>? _banSubscription;
  Map<String, dynamic>? _banScreenConfig;
  bool _wasUnbanned = false; // Track if recovered from ban

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
    _startBanListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _banSubscription?.cancel();
    _isBanned.dispose();
    super.dispose();
  }

  void _startHeartbeat() {
    // Send heartbeat every 2 minutes to keep device "online"
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _firebaseService.sendHeartbeat();
    });
    // Also send initial heartbeat
    _firebaseService.sendHeartbeat();
    debugPrint('💓 Heartbeat started (every 2 minutes)');
  }

  void _startBanListener() {
    debugPrint('🚫 Starting ban status listener...');
    _banSubscription = _firebaseService.listenToBanStatus().listen((isBanned) async {
      debugPrint('🚫 Ban status update: $isBanned');
      
      if (isBanned && !_isBanned.value) {
        // Device just got banned - load SDUI config and stop heartbeat
        _banScreenConfig = await _firebaseService.getBanScreenConfig();
        _heartbeatTimer?.cancel();
        _wasUnbanned = false;
        debugPrint('🚫 BANNED! Showing ban screen...');
      } else if (!isBanned && _isBanned.value) {
        // Device just got unbanned - restart heartbeat and set online
        debugPrint('✅ UNBANNED! Restarting normal operations...');
        _wasUnbanned = true;
        await _firebaseService.updateDeviceStatus('online');
        _startHeartbeat();
      }
      
      _isBanned.value = isBanned;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Don't update status if device is banned
    if (_isBanned.value) {
      debugPrint('📱 App lifecycle changed but device is BANNED - ignoring');
      return;
    }
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground
        debugPrint('📱 App RESUMED - setting online');
        _firebaseService.updateDeviceStatus('online');
        _startHeartbeat();
        break;
      case AppLifecycleState.paused:
        // App went to background
        debugPrint('📱 App PAUSED - heartbeat stopped');
        _heartbeatTimer?.cancel();
        // Don't set offline immediately - let the timeout handle it
        break;
      case AppLifecycleState.detached:
        // App is about to be killed
        debugPrint('📱 App DETACHED');
        _heartbeatTimer?.cancel();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: _userManager.currentLocale,
      builder: (context, locale, _) {
        debugPrint('🌐 MaterialApp rebuilding with locale: ${locale.languageCode}_${locale.countryCode}');
    return ValueListenableBuilder<bool>(
      valueListenable: _isBanned,
      builder: (context, isBanned, _) {
        // If banned, show full-screen ban screen
        if (isBanned) {
          return MaterialApp(
                key: ValueKey('banned_${locale.languageCode}_${locale.countryCode}'),
            debugShowCheckedModeBanner: false,
                locale: locale,
                supportedLocales: const [
                  Locale('en', 'US'),
                  Locale('my', 'MM'),
                  Locale('ja', 'JP'),
                  Locale('zh', 'CN'),
                  Locale('th', 'TH'),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
            home: BannedScreen(config: _banScreenConfig),
          );
        }
        
        // Normal app flow
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, themeMode, child) {
            return MaterialApp(
                  // Force rebuild when locale changes
                  key: ValueKey('app_${locale.languageCode}_${locale.countryCode}'),
              title: 'Suk Fhyoke VPN',
              debugShowCheckedModeBanner: false,
              themeMode: themeMode,
                  locale: locale,
                  supportedLocales: const [
                    Locale('en', 'US'),
                    Locale('my', 'MM'),
                    Locale('ja', 'JP'),
                    Locale('zh', 'CN'),
                    Locale('th', 'TH'),
                  ],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.light(
              primary: VPNApp.lightPrimaryPurple,
              secondary: VPNApp.lightSecondaryPurple,
              surface: VPNApp.lightSurface,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: const Color(0xFF2D2D2D),
            ),
            scaffoldBackgroundColor: VPNApp.lightBackground,
            cardColor: VPNApp.lightCardColor,
            dividerColor: Colors.grey.shade200,
            appBarTheme: AppBarTheme(
              backgroundColor: VPNApp.lightBackground,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              iconTheme: IconThemeData(color: Colors.grey.shade800),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: VPNApp.lightPrimaryPurple,
                foregroundColor: Colors.white,
              ),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return VPNApp.lightPrimaryPurple;
                }
                return Colors.grey.shade400;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return VPNApp.lightSecondaryPurple.withOpacity(0.5);
                }
                return Colors.grey.shade300;
              }),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.dark(
              primary: VPNApp.darkPrimaryPurple,
              secondary: VPNApp.darkSecondaryPurple,
              surface: VPNApp.darkSurface,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: const Color(0xFFE8E8E8),
            ),
            scaffoldBackgroundColor: VPNApp.darkBackground,
            cardColor: VPNApp.darkCardColor,
            dividerColor: Colors.purple.shade900,
            appBarTheme: AppBarTheme(
              backgroundColor: VPNApp.darkBackground,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: VPNApp.darkPrimaryPurple,
                foregroundColor: Colors.white,
              ),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return VPNApp.darkPrimaryPurple;
                }
                return Colors.grey.shade600;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return VPNApp.darkSecondaryPurple.withOpacity(0.5);
                }
                return Colors.grey.shade800;
              }),
            ),
          ),
          // Use builder to wrap all screens with the correct SystemUiOverlayStyle
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                // Status Bar - match background color
                statusBarColor: isDark ? VPNApp.darkBackground : VPNApp.lightBackground,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                
                // Navigation Bar - match background color
                systemNavigationBarColor: isDark ? VPNApp.darkBackground : VPNApp.lightBackground,
                systemNavigationBarDividerColor: isDark ? VPNApp.darkBackground : VPNApp.lightBackground,
                systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              ),
              child: child!,
            );
          },
            // If just unbanned, go directly to HomeScreen; otherwise show SplashScreen
            home: _wasUnbanned ? const HomeScreen() : const SplashScreen(),
          );
        },
      );
      },
        );
      }
    );
  }
}
