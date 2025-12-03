import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'message_dialog.dart'; // Reusing your dialog styles

class ReviewUtils {
  static const String _keyInstallTime = 'install_timestamp';
  static const String _keyReviewRequested = 'review_requested';
  // Replace with your actual Play Store package name
  static const String _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.vpnapp'; 

  /// Checks if 48 hours have passed since installation and review hasn't been requested yet.
  static Future<void> checkAndRequestReview(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Check if review already requested
    if (prefs.getBool(_keyReviewRequested) == true) {
      return;
    }

    // 2. Get or set install time
    int? installTimestamp = prefs.getInt(_keyInstallTime);
    if (installTimestamp == null) {
      // First run, set timestamp
      installTimestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_keyInstallTime, installTimestamp);
      return; // Don't show immediately on first run
    }

    // 3. Check if 48 hours passed
    final installTime = DateTime.fromMillisecondsSinceEpoch(installTimestamp);
    final now = DateTime.now();
    final difference = now.difference(installTime);

    if (difference.inHours >= 48) {
      if (context.mounted) {
        _showReviewDialog(context, prefs);
      }
    }
  }

  static void _showReviewDialog(BuildContext context, SharedPreferences prefs) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allow custom height
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;

        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_rounded, color: Colors.amber, size: 36),
                  ),
                  const SizedBox(height: 12),
                  
                  // Title
                  Text(
                    'Enjoying our VPN?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // Message
                  Text(
                    'If you like using our app, would you mind taking a moment to rate it on Play Store? Thanks for your support!',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  // Rate Now Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await prefs.setBool(_keyReviewRequested, true);
                        
                        final Uri url = Uri.parse(_playStoreUrl);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Rate Now ⭐',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Remind Me Later & No Thanks in Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text('•', style: TextStyle(color: Colors.grey.shade400)),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await prefs.setBool(_keyReviewRequested, true);
                        },
                        child: Text(
                          'No Thanks',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// For testing purposes: Reset review status and set install time to 49 hours ago
  static Future<void> debugResetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyReviewRequested);
    // Set install time to 49 hours ago
    final pastTime = DateTime.now().subtract(const Duration(hours: 49));
    await prefs.setInt(_keyInstallTime, pastTime.millisecondsSinceEpoch);
    debugPrint("ReviewUtils: Reset for testing. Install time set to 49 hours ago.");
  }
}

