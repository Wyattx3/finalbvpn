import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/localization_service.dart';
import '../services/sdui_service.dart';

/// Server Maintenance Screen - Simple clean design
/// Shows: Logo, Progress bar, Text only on white background
class ServerMaintenanceScreen extends StatefulWidget {
  final Map<String, dynamic> config;

  const ServerMaintenanceScreen({
    super.key,
    required this.config,
  });

  @override
  State<ServerMaintenanceScreen> createState() => _ServerMaintenanceScreenState();
}

class _ServerMaintenanceScreenState extends State<ServerMaintenanceScreen>
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

  @override
  Widget build(BuildContext context) {
    // SDUI Config values with defaults (supports multi-language)
    final title = _sduiService.getText(widget.config['title'], _l.tr('under_maintenance'));
    final message = _sduiService.getText(widget.config['message'], 
        'We\'re currently performing scheduled maintenance.\nPlease check back soon.');
    final estimatedTime = _sduiService.getText(widget.config['estimated_time'], '');
    final showProgress = widget.config['show_progress'] as bool? ?? true;
    final progressText = _sduiService.getText(widget.config['progress_text'], 'Working on it...');

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.shield_outlined,
                              size: 50,
                              color: Colors.deepPurple.shade400,
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
                
                      // Estimated Time (if provided)
                if (estimatedTime.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Est. Time: $estimatedTime',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                
                // Progress Indicator
                if (showProgress) ...[
                        const SizedBox(height: 40),
                  SizedBox(
                    width: 200,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.deepPurple.shade400,
                      ),
                    ),
                  ),
                        ),
                        const SizedBox(height: 12),
                            Text(
                          progressText,
                              style: TextStyle(
                                fontSize: 12,
                            color: Colors.grey.shade500,
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
      );
  }
}
