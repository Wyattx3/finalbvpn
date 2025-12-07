import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Server Maintenance Screen - shown when server is under maintenance
/// Configurable via SDUI from admin dashboard
class ServerMaintenanceScreen extends StatelessWidget {
  final Map<String, dynamic> config;

  const ServerMaintenanceScreen({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final title = config['title'] as String? ?? 'Under Maintenance';
    final message = config['message'] as String? ?? 
        'We\'re currently performing scheduled maintenance.\nPlease check back soon.';
    final estimatedTime = config['estimated_time'] as String? ?? '';
    final showProgress = config['show_progress'] as bool? ?? true;
    final backgroundColor = config['background_color'] as String? ?? '#1a1a2e';
    final titleColor = config['title_color'] as String? ?? '#ffffff';
    final messageColor = config['message_color'] as String? ?? '#b0b0b0';
    final image = config['image'] as String?;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _parseColor(backgroundColor),
                _parseColor(backgroundColor).withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image or Icon
                if (image != null && image.isNotEmpty)
                  _buildImage(image)
                else
                  _buildDefaultIcon(),
                
                const SizedBox(height: 40),
                
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _parseColor(titleColor),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: _parseColor(messageColor),
                      height: 1.6,
                    ),
                  ),
                ),
                
                // Estimated Time
                if (estimatedTime.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 20,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Est. Time: $estimatedTime',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Progress Indicator
                if (showProgress) ...[
                  const SizedBox(height: 50),
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF7E57C2).withOpacity(0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Working on it...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
                
                const SizedBox(height: 60),
                
                // Info Box
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E57C2).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.engineering_rounded,
                          color: Color(0xFF7E57C2),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Why maintenance?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'We\'re improving our servers for better performance.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String image) {
    if (image.startsWith('data:image/')) {
      // Base64 image
      final base64Data = image.split(',').last;
      return Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.memory(
            base64Decode(base64Data),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // URL image
      return Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
          ),
        ),
      );
    }
  }

  Widget _buildDefaultIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF7E57C2).withOpacity(0.3),
                  const Color(0xFF9575CD).withOpacity(0.2),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF7E57C2).withOpacity(0.5),
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.build_circle_rounded,
              size: 70,
              color: Color(0xFFB39DDB),
            ),
          ),
        );
      },
    );
  }

  Color _parseColor(String hexColor) {
    try {
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('FF$hexColor', radix: 16));
      }
      return Colors.white;
    } catch (e) {
      return Colors.white;
    }
  }
}

