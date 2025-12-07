import 'dart:io';
import 'package:flutter/material.dart';

/// Network utility functions for checking connectivity
class NetworkUtils {
  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on Exception catch (_) {
      return false;
    }
  }

  /// Show network error dialog
  static void showNetworkErrorDialog(BuildContext context, {VoidCallback? onRetry}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.red.shade400, size: 28),
            const SizedBox(width: 12),
            const Text('No Connection'),
          ],
        ),
        content: const Text(
          'Please check your internet connection and try again.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRetry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E57C2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  /// Show network error snackbar
  static void showNetworkErrorSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text('No internet connection. Please try again.'),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Wrapper for async operations with network check
  static Future<T?> withNetworkCheck<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    VoidCallback? onNoConnection,
    bool showDialog = true,
  }) async {
    final hasConnection = await hasInternetConnection();
    
    if (!hasConnection) {
      if (context.mounted) {
        if (showDialog) {
          showNetworkErrorDialog(context);
        } else {
          showNetworkErrorSnackBar(context);
        }
      }
      onNoConnection?.call();
      return null;
    }
    
    try {
      return await operation();
    } catch (e) {
      debugPrint('❌ Network operation error: $e');
      if (context.mounted) {
        if (e.toString().contains('UNAVAILABLE') || 
            e.toString().contains('UnknownHostException') ||
            e.toString().contains('SocketException')) {
          if (showDialog) {
            showNetworkErrorDialog(context);
          } else {
            showNetworkErrorSnackBar(context);
          }
        }
      }
      rethrow;
    }
  }
}

