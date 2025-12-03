import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MessageType { success, error, info, warning }

/// Shows a half screen bottom modal dialog with a message.
/// 
/// [context] - BuildContext
/// [message] - The message to display
/// [type] - The type of message (success, error, info, warning)
/// [title] - Optional title for the dialog
void showMessageDialog(
  BuildContext context, {
  required String message,
  MessageType type = MessageType.info,
  String? title,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final backgroundColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);
  final dialogColor = isDark ? const Color(0xFF2D2640) : Colors.white;
  
  // Set system bar color to match theme (NOT transparent)
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: backgroundColor,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
  ));
  
  IconData icon;
  Color iconColor;
  String defaultTitle;
  
  switch (type) {
    case MessageType.success:
      icon = Icons.check_circle;
      iconColor = Colors.green;
      defaultTitle = 'Success';
      break;
    case MessageType.error:
      icon = Icons.error;
      iconColor = Colors.red;
      defaultTitle = 'Error';
      break;
    case MessageType.warning:
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.orange;
      defaultTitle = 'Warning';
      break;
    case MessageType.info:
    default:
      icon = Icons.info;
      iconColor = Colors.blue;
      defaultTitle = 'Info';
      break;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: dialogColor,
    isDismissible: false, // Cannot dismiss by tapping outside
    enableDrag: false, // Cannot dismiss by dragging
    isScrollControlled: false, // Half screen
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext ctx) {
      return WillPopScope(
        onWillPop: () async => false, // Disable back button dismiss
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 48),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                title ?? defaultTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 28),
              
              // OK Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Shows a half screen confirmation dialog with Yes/No options.
/// 
/// Returns true if confirmed, false otherwise.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String message,
  String? title,
  String confirmText = 'Yes',
  String cancelText = 'No',
  Color confirmColor = Colors.deepPurple,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final backgroundColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);
  final dialogColor = isDark ? const Color(0xFF2D2640) : Colors.white;
  
  // Set system bar color to match theme (NOT transparent)
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: backgroundColor,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
  ));
  
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: dialogColor,
    isDismissible: false, // Cannot dismiss by tapping outside
    enableDrag: false, // Cannot dismiss by dragging
    isScrollControlled: false, // Half screen
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext ctx) {
      return WillPopScope(
        onWillPop: () async => false, // Disable back button dismiss
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.help_outline, color: Colors.orange, size: 48),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                title ?? 'Confirm',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 28),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          side: BorderSide(color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          cancelText,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          confirmText,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  
  return result ?? false;
}
