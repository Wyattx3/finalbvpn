import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import '../services/sdui_service.dart';
import '../services/firebase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final SduiService _sduiService = SduiService();
  final FirebaseService _firebaseService = FirebaseService();
  
  // SDUI Config
  int _splashDuration = 3;
  
  // Loading progress
  double _progress = 0.0;
  String _statusText = 'Initializing...';

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Step 1: Load SDUI config (20%)
    _updateProgress(0.1, 'Loading config...');
    try {
      final response = await _sduiService.getScreenConfig('splash');
      if (response.containsKey('config')) {
        final config = response['config'];
        _splashDuration = config['splash_duration_seconds'] ?? 3;
      }
      _updateProgress(0.2, 'Config loaded ✓');
    } catch (e) {
      debugPrint('⚠️ SDUI config error: $e');
      _updateProgress(0.2, 'Using defaults');
    }

    // Step 2: Initialize Firebase (60%)
    _updateProgress(0.3, 'Connecting to server...');
    try {
      final result = await _firebaseService.initialize();
      _updateProgress(0.6, result ? 'Connected ✓' : 'Offline mode');
      debugPrint('🔥 Firebase initialization: ${result ? "SUCCESS" : "FAILED"}');
    } catch (e) {
      debugPrint('❌ Firebase error: $e');
      _updateProgress(0.6, 'Connection error');
    }

    // Step 3: Load servers (90%)
    _updateProgress(0.7, 'Loading servers...');
    try {
      final servers = await _firebaseService.getServers();
      debugPrint('📡 Loaded ${servers.length} servers from Firebase');
      _updateProgress(0.9, '${servers.length} servers ready');
    } catch (e) {
      debugPrint('⚠️ Servers error: $e');
      _updateProgress(0.9, 'Offline mode');
    }

    // Complete (100%)
    _updateProgress(1.0, 'Ready!');
    
    // Wait for remaining splash duration
    await Future.delayed(Duration(seconds: _splashDuration > 1 ? _splashDuration - 1 : 1));
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  void _updateProgress(double progress, String status) {
    if (mounted) {
      setState(() {
        _progress = progress;
        _statusText = status;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Main content - Logo centered
              Expanded(
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Image.asset(
                          'assets/images/splash_logo.png',
                          width: 280,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Bottom section - Progress bar and status
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
                child: Column(
                  children: [
                    // Status text
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _statusText,
                        key: ValueKey(_statusText),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: _progress),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, child) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF2196F3), // Blue color to match logo
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Percentage
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
