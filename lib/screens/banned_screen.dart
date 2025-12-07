import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

/// Full-screen Banned Screen - Shows when device is banned
/// Configured via SDUI from Firebase
class BannedScreen extends StatelessWidget {
  final Map<String, dynamic>? config;
  
  const BannedScreen({super.key, this.config});

  // Default config if SDUI not available
  Map<String, dynamic> get _config => config ?? {
    'title': 'Account Suspended',
    'message': 'Your account has been suspended due to violation of our terms of service.',
    'image': 'assets/images/banned.png',
    'support_button': {
      'text': 'Contact Support',
      'url': 'https://t.me/bvpn_support',
    },
    'quit_button': {
      'text': 'Quit App',
    },
    'background_gradient': ['#1A1625', '#2D2640'],
  };

  Future<void> _contactSupport() async {
    final supportUrl = _config['support_button']?['url'] ?? 'https://t.me/bvpn_support';
    final uri = Uri.parse(supportUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _quitApp() {
    // Exit the app
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _config['title'] ?? 'Account Suspended';
    final message = _config['message'] ?? 'Your account has been suspended.';
    final imagePath = _config['image'] ?? 'assets/images/banned.png';
    final supportButtonText = _config['support_button']?['text'] ?? 'Contact Support';
    final quitButtonText = _config['quit_button']?['text'] ?? 'Quit App';

    return PopScope(
      canPop: false, // Prevent back button
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Full screen background image
              Image.asset(
                imagePath,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF1A1625),
                    child: const Center(
                      child: Icon(Icons.block, size: 100, color: Colors.red),
                    ),
                  );
                },
              ),
              
              // Dark overlay for better text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.0, 0.4, 0.6, 1.0],
                  ),
                ),
              ),
              
              // Content
              SafeArea(
                child: Column(
                  children: [
                    // Spacer to push content to bottom
                    const Spacer(),
                    
                    // Content Section at bottom
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Message
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.85),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 28),
                          
                          // Contact Support Button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _contactSupport,
                              icon: const Icon(Icons.support_agent, size: 22),
                              label: Text(
                                supportButtonText,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7E57C2),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Quit Button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton.icon(
                              onPressed: _quitApp,
                              icon: const Icon(Icons.exit_to_app, size: 22),
                              label: Text(
                                quitButtonText,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
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

