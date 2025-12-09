import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../services/localization_service.dart';
import '../services/sdui_service.dart';
import '../user_manager.dart';

/// Banned Screen - Simple clean design
/// Shows: Logo, Text, Buttons only on white background
class BannedScreen extends StatefulWidget {
  final Map<String, dynamic>? config;
  
  const BannedScreen({super.key, this.config});

  @override
  State<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends State<BannedScreen>
    with SingleTickerProviderStateMixin {
  final LocalizationService _l = LocalizationService();
  final SduiService _sduiService = SduiService();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Default config if SDUI not available
  Map<String, dynamic> get _config => widget.config ?? {
    'title': 'Account Suspended',
    'message': 'Your account has been suspended due to violation of our terms of service.',
    'support_button': {
      'text': 'Contact Support',
      'url': 'https://t.me/bvpn_support',
    },
    'quit_button': {
      'text': 'Quit App',
    },
  };

  Future<void> _contactSupport() async {
    final supportUrl = _config['support_button']?['url'] ?? 'https://t.me/bvpn_support';
    final uri = Uri.parse(supportUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _quitApp() {
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _sduiService.getText(_config['title'], _l.tr('account_suspended'));
    final message = _sduiService.getText(_config['message'], 'Your account has been suspended.');
    final supportButtonText = _sduiService.getText(_config['support_button']?['text'], 'Contact Support');
    final quitButtonText = _sduiService.getText(_config['quit_button']?['text'], 'Quit App');
    final showQuitButton = _config['show_quit_button'] ?? true;

    return PopScope(
      canPop: false, // Prevent back button
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
            children: [
                        // App Logo
              Image.asset(
                          'assets/images/app_icon.png',
                          width: 100,
                          height: 100,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.block_outlined,
                                size: 50,
                                color: Colors.red.shade400,
                    ),
                  );
                },
              ),
              
                        const SizedBox(height: 40),
                        
                          // Title
                          Text(
                            title,
                          textAlign: TextAlign.center,
                            style: const TextStyle(
                            fontSize: 24,
                              fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                            letterSpacing: 0.5,
                            ),
                          ),
                          
                        const SizedBox(height: 16),
                          
                          // Message
                          Text(
                            message,
                          textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                            color: Colors.grey.shade600,
                            height: 1.6,
                            ),
                          ),
                          
                        const SizedBox(height: 40),
                          
                          // Contact Support Button
                          SizedBox(
                            width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                              onPressed: _contactSupport,
                              style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            child: Text(
                              supportButtonText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            ),
                          ),
                          
                        // Quit Button (optional)
                        if (showQuitButton) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: TextButton(
                              onPressed: _quitApp,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade600,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                quitButtonText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                  ],
                ),
              ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
