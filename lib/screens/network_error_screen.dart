import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Local fallback screen for network/Firebase connection errors
class NetworkErrorScreen extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;

  const NetworkErrorScreen({
    super.key,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1a1a2e),
                Color(0xFF16213e),
                Color(0xFF0f3460),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon with animation
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          size: 60,
                          color: Colors.white70,
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Title
                const Text(
                  'Connection Error',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    errorMessage ?? 'Unable to connect to server.\nPlease check your internet connection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 50),
                
                // Retry Button
                if (onRetry != null)
                  GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7E57C2), Color(0xFF9575CD)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7E57C2).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 30),
                
                // Tips
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
                  child: Column(
                    children: [
                      Text(
                        'Tips',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTip(Icons.wifi, 'Check your WiFi connection'),
                      const SizedBox(height: 8),
                      _buildTip(Icons.signal_cellular_alt, 'Check mobile data'),
                      const SizedBox(height: 8),
                      _buildTip(Icons.airplanemode_active, 'Turn off airplane mode'),
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

  Widget _buildTip(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.white.withOpacity(0.5),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

