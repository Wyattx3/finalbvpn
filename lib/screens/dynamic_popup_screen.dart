import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sdui_service.dart';

/// Display type for the dynamic popup
enum PopupDisplayType {
  popup,       // Center dialog
  bottomSheet, // Modal bottom sheet
  fullScreen,  // Full screen page
}

/// Helper function to show dynamic popup based on config
void showDynamicPopup(BuildContext context, Map<String, dynamic> config) {
  final displayType = _parseDisplayType(config['display_type'] ?? 'popup');
  final bool isDismissible = config['is_dismissible'] ?? true;

  switch (displayType) {
    case PopupDisplayType.fullScreen:
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) => _FullScreenPopup(config: config),
        ),
      );
      break;
    case PopupDisplayType.bottomSheet:
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: isDismissible,
        enableDrag: isDismissible,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _BottomSheetPopup(config: config),
      );
      break;
    case PopupDisplayType.popup:
    default:
      showDialog(
        context: context,
        barrierDismissible: isDismissible,
        builder: (ctx) => _CenterPopup(config: config),
      );
      break;
  }
}

PopupDisplayType _parseDisplayType(String type) {
  switch (type.toLowerCase()) {
    case 'full_screen':
    case 'fullscreen':
      return PopupDisplayType.fullScreen;
    case 'bottom_sheet':
    case 'bottomsheet':
    case 'bottom':
      return PopupDisplayType.bottomSheet;
    case 'popup':
    case 'dialog':
    case 'center':
    default:
      return PopupDisplayType.popup;
  }
}

Color? _parseColor(dynamic colorValue) {
  if (colorValue == null) return null;
  
  String? hexString;
  if (colorValue is String) {
    hexString = colorValue;
  } else {
    debugPrint('🎨 Color value is not a string: $colorValue (${colorValue.runtimeType})');
    return null;
  }
  
  if (hexString.isEmpty) return null;
  
  try {
    // Handle various formats: #FFFFFF, FFFFFF, 0xFFFFFFFF
    String cleanHex = hexString.trim();
    if (cleanHex.startsWith('#')) {
      cleanHex = cleanHex.substring(1);
    } else if (cleanHex.startsWith('0x') || cleanHex.startsWith('0X')) {
      cleanHex = cleanHex.substring(2);
    }
    
    // Add alpha if missing (6 chars = RGB, need ARGB)
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    
    final color = Color(int.parse(cleanHex, radix: 16));
    debugPrint('🎨 Parsed color: $hexString -> $color');
    return color;
  } catch (e) {
    debugPrint('🎨 ❌ Color parse error: $hexString -> $e');
    return null;
  }
}

void _handleAction(BuildContext context, String? action, String? target, {Map<String, dynamic>? config}) async {
  if (action == null) return;

  debugPrint('🔘 Button action: $action, target: $target');
  
  // Check if this is a forced update popup
  final String? popupType = config?['popup_type'] as String?;
  final bool isDismissible = config?['is_dismissible'] ?? true;
  final bool needsUpdate = config?['_needs_update'] ?? false; // Version check result from home_screen
  // FORCE UPDATE: When update is needed, user CANNOT dismiss (regardless of is_dismissible setting)
  final bool isForceUpdate = config != null && 
      popupType == 'update' && 
      needsUpdate == true; // Always force when update is needed!

  debugPrint('🔘 Force update check: popup_type=$popupType, is_dismissible=$isDismissible, needsUpdate=$needsUpdate, isForceUpdate=$isForceUpdate');

  switch (action) {
    case 'close':
    case 'dismiss':
      // If it's a forced update popup, NEVER allow dismiss
      if (isForceUpdate) {
        debugPrint('🔘 ❌ Dismiss BLOCKED - Update Required! User MUST update the app.');
        // Show a snackbar message instead
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('အက်ပ်ကို Update လုပ်မှ ဆက်သုံးလို့ရပါမည်'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return; // Don't close the popup - user MUST update
      }
      
      debugPrint('🔘 ✅ Dismiss allowed - closing popup');
      Navigator.pop(context);
      break;
    case 'update':
      // Open Play Store for app update
      try {
        const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.sukfhyoke.vpn';
        final Uri url = Uri.parse(playStoreUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('❌ Error opening Play Store: $e');
      }
      // Don't close popup for forced updates
      if (!isForceUpdate) {
        Navigator.pop(context);
      }
      break;
    case 'link':
    case 'open_url':
      debugPrint('🔗 open_url action triggered');
      debugPrint('🔗 target value: "$target"');
      debugPrint('🔗 target is null: ${target == null}');
      debugPrint('🔗 target is empty: ${target?.isEmpty}');
      
      if (target != null && target.isNotEmpty) {
        try {
          // Auto-add https:// if missing
          String urlString = target;
          if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
            urlString = 'https://$urlString';
            debugPrint('🔗 Added https:// prefix: $urlString');
          }
          
          final Uri url = Uri.parse(urlString);
          debugPrint('🔗 Parsed URL: $url');
          debugPrint('🔗 URL scheme: ${url.scheme}');
          
          final canLaunch = await canLaunchUrl(url);
          debugPrint('🔗 canLaunchUrl result: $canLaunch');
          
          if (canLaunch) {
            debugPrint('🔗 Launching URL now...');
            await launchUrl(url, mode: LaunchMode.externalApplication);
            debugPrint('🔗 ✅ URL launched successfully');
          } else {
            debugPrint('❌ Cannot launch URL: $url');
          }
        } catch (e) {
          debugPrint('❌ Error launching URL: $e');
        }
      } else {
        debugPrint('❌ Target URL is null or empty!');
      }
      Navigator.pop(context);
      break;
    case 'navigate':
      if (target != null) {
        Navigator.pop(context);
        Navigator.pushNamed(context, target);
      }
      break;
    case 'exit_app':
      SystemNavigator.pop();
      break;
    default:
      // Default to dismiss for unknown actions
      Navigator.pop(context);
      break;
  }
}

/// ============ CENTER POPUP (Dialog) ============
class _CenterPopup extends StatelessWidget {
  final Map<String, dynamic> config;
  final SduiService _sduiService = SduiService();

  _CenterPopup({required this.config});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> style = config['style'] ?? {};
    final backgroundColor = _parseColor(config['background_color']) ?? _parseColor(style['background_color']) ?? Colors.white;
    final bool isDarkBg = backgroundColor.computeLuminance() < 0.5;
    final bool isDismissible = config['is_dismissible'] ?? true;
    
    // Check if this is a force update popup
    final String? popupType = config['popup_type'] as String?;
    final bool needsUpdate = config['_needs_update'] ?? false;
    final bool isForceUpdate = popupType == 'update' && needsUpdate;
    
    // For force update, NEVER allow dismiss
    final bool canDismiss = isDismissible && !isForceUpdate;
    
    // Get translated text using SduiService
    final String? title = config['title'] != null ? _sduiService.getText(config['title']) : null;
    final String? message = config['message'] != null ? _sduiService.getText(config['message']) : null;
    
    // Check for image (support both 'image' and 'image_url' keys)
    final String? imageUrl = config['image'] as String? ?? config['image_url'] as String?;
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    
    // Debug color values
    debugPrint('🎨 ======= POPUP COLORS =======');
    debugPrint('🎨 title_color raw: ${config['title_color']}');
    debugPrint('🎨 message_color raw: ${config['message_color']}');
    debugPrint('🎨 button_color raw: ${config['button_color']}');
    debugPrint('🎨 button_text_color raw: ${config['button_text_color']}');
    debugPrint('🖼️ Popup image URL: $imageUrl');
    debugPrint('🖼️ hasImage: $hasImage');
    debugPrint('🔒 isForceUpdate: $isForceUpdate, canDismiss: $canDismiss');

    return PopScope(
      canPop: canDismiss,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isForceUpdate) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('အက်ပ်ကို Update လုပ်မှ ဆက်သုံးလို့ရပါမည်'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: BoxConstraints(maxWidth: 400, maxHeight: hasImage ? 600 : 500),
          decoration: BoxDecoration(
            color: hasImage ? Colors.transparent : backgroundColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Full Background Image
                if (hasImage)
                  Positioned.fill(
                    child: _buildBackgroundImage(imageUrl),
                  ),
                
                // Light overlay for text readability
                if (hasImage)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(0.4),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // No image - solid background
                if (!hasImage)
                  Positioned.fill(
                    child: Container(color: backgroundColor),
                  ),

                // Content - fill entire dialog
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Close button (top right) - HIDDEN for force update
                      if (canDismiss)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: hasImage || isDarkBg ? Colors.white70 : Colors.grey,
                            ),
                          ),
                        ),

                      // Spacer to push content down when image is background
                      if (hasImage) const Spacer(),

                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          if (title != null && title.isNotEmpty)
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: (style['title_size'] ?? 22).toDouble(),
                                fontWeight: FontWeight.bold,
                                color: _parseColor(config['title_color']) ?? _parseColor(style['title_color']) ?? (hasImage || isDarkBg ? Colors.white : Colors.deepPurple),
                              ),
                            ),
                          if (title != null && title.isNotEmpty) const SizedBox(height: 12),

                          // Message
                          if (message != null && message.isNotEmpty)
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: (style['message_size'] ?? 15).toDouble(),
                                color: _parseColor(config['message_color']) ?? _parseColor(style['message_color']) ?? (hasImage || isDarkBg ? Colors.grey.shade300 : Colors.grey.shade600),
                                height: 1.5,
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Buttons
                          _buildButtons(context, config['buttons'], style, config),
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
}

Widget _buildBackgroundImage(String imageUrl) {
  debugPrint('🖼️ Loading background image (length: ${imageUrl.length})');
  
  // Handle base64 images (data:image/...)
  if (imageUrl.startsWith('data:image/')) {
    try {
      final base64Data = imageUrl.split(',').last;
      final bytes = base64Decode(base64Data);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('🖼️ ❌ Base64 image error: $error');
          return Container(
            color: Colors.grey.shade800,
            child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
          );
        },
      );
    } catch (e) {
      debugPrint('🖼️ ❌ Base64 decode error: $e');
      return Container(
        color: Colors.grey.shade800,
        child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
      );
    }
  }
  
  // Handle network images (http/https)
  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey.shade800,
          child: const Center(child: CircularProgressIndicator(color: Colors.white54)),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('🖼️ ❌ Network image error: $error');
        return Container(
          color: Colors.grey.shade800,
          child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
        );
      },
    );
  }
  
  // Handle asset images
  if (imageUrl.startsWith('assets/') || imageUrl.startsWith('assets\\')) {
    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('🖼️ ❌ Asset image error: $error');
        return Container(
          color: Colors.grey.shade800,
          child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)),
        );
      },
    );
  }
  
  debugPrint('🖼️ ⚠️ Unknown image format');
  return Container(
    color: Colors.grey.shade800,
    child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white54, size: 48)),
  );
}

/// ============ BOTTOM SHEET POPUP ============
class _BottomSheetPopup extends StatelessWidget {
  final Map<String, dynamic> config;
  final SduiService _sduiService = SduiService();

  _BottomSheetPopup({required this.config});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> style = config['style'] ?? {};
    final backgroundColor = _parseColor(config['background_color']) ?? _parseColor(style['background_color']) ?? Colors.white;
    final bool isDarkBg = backgroundColor.computeLuminance() < 0.5;
    final bool isDismissible = config['is_dismissible'] ?? true;
    
    // Check if this is a force update popup
    final String? popupType = config['popup_type'] as String?;
    final bool needsUpdate = config['_needs_update'] ?? false;
    final bool isForceUpdate = popupType == 'update' && needsUpdate;
    
    // For force update, NEVER allow dismiss
    final bool canDismiss = isDismissible && !isForceUpdate;
    
    // Get translated text using SduiService
    final String? title = config['title'] != null ? _sduiService.getText(config['title']) : null;
    final String? message = config['message'] != null ? _sduiService.getText(config['message']) : null;
    
    // Check for image (support both 'image' and 'image_url' keys)
    final String? imageUrl = config['image'] as String? ?? config['image_url'] as String?;
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    // Debug colors
    debugPrint('🎨 BottomSheet title_color: ${config['title_color']}');
    debugPrint('🎨 BottomSheet message_color: ${config['message_color']}');
    debugPrint('🎨 BottomSheet button_color: ${config['button_color']}');

    return PopScope(
      canPop: canDismiss,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isForceUpdate) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('အက်ပ်ကို Update လုပ်မှ ဆက်သုံးလို့ရပါမည်'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5, // 50% of screen
          minHeight: hasImage ? 280 : 180,
        ),
        decoration: BoxDecoration(
          color: hasImage ? Colors.transparent : backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Stack(
            children: [
              // Full Background Image
              if (hasImage)
                Positioned.fill(
                  child: _buildBackgroundImage(imageUrl),
                ),
              
              // Light overlay for text readability
              if (hasImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // No image - solid background
              if (!hasImage)
                Positioned.fill(
                  child: Container(color: backgroundColor),
                ),

              // Content - full width
              SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: hasImage || isDarkBg ? Colors.white54 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Close button (top right) - HIDDEN for force update
                      if (canDismiss)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: hasImage || isDarkBg ? Colors.white70 : Colors.grey,
                            ),
                          ),
                        ),

                      // Spacer to push content down when image is background
                      if (hasImage) const Spacer(),

                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        children: [
                          // Title
                          if (title != null && title.isNotEmpty)
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: (style['title_size'] ?? 22).toDouble(),
                                fontWeight: FontWeight.bold,
                                color: _parseColor(config['title_color']) ?? _parseColor(style['title_color']) ?? (hasImage || isDarkBg ? Colors.white : Colors.deepPurple),
                              ),
                            ),
                          if (title != null && title.isNotEmpty) const SizedBox(height: 12),

                          // Message
                          if (message != null && message.isNotEmpty)
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: (style['message_size'] ?? 15).toDouble(),
                                color: _parseColor(config['message_color']) ?? _parseColor(style['message_color']) ?? (hasImage || isDarkBg ? Colors.grey.shade300 : Colors.grey.shade600),
                                height: 1.5,
                              ),
                            ),

                          const SizedBox(height: 28),

                          // Buttons
                          _buildButtons(context, config['buttons'], style, config),
                        ],
                      ),
                    ),
                  ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============ FULL SCREEN POPUP ============
class _FullScreenPopup extends StatelessWidget {
  final Map<String, dynamic> config;
  final SduiService _sduiService = SduiService();

  _FullScreenPopup({required this.config});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> style = config['style'] ?? {};
    final backgroundColor = _parseColor(config['background_color']) ?? _parseColor(style['background_color']) ?? Colors.white;
    final bool isDarkBg = backgroundColor.computeLuminance() < 0.5;
    final bool isDismissible = config['is_dismissible'] ?? true;
    
    // Check if this is a force update popup
    final String? popupType = config['popup_type'] as String?;
    final bool needsUpdate = config['_needs_update'] ?? false;
    final bool isForceUpdate = popupType == 'update' && needsUpdate;
    
    // For force update, NEVER allow dismiss
    final bool canDismiss = isDismissible && !isForceUpdate;
    
    // Get translated text using SduiService
    final String? title = config['title'] != null ? _sduiService.getText(config['title']) : null;
    final String? message = config['message'] != null ? _sduiService.getText(config['message']) : null;
    
    // Check for image (support both 'image' and 'image_url' keys)
    final String? imageUrl = config['image'] as String? ?? config['image_url'] as String?;
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return PopScope(
      canPop: canDismiss,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isForceUpdate) {
          // Show message when user tries to go back
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('အက်ပ်ကို Update လုပ်မှ ဆက်သုံးလို့ရပါမည်'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: hasImage ? Colors.transparent : backgroundColor,
          statusBarIconBrightness: hasImage || isDarkBg ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: hasImage ? Colors.black : backgroundColor,
          systemNavigationBarIconBrightness: hasImage || isDarkBg ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: hasImage ? Colors.black : backgroundColor,
          body: Stack(
            children: [
              // Full Background Image
              if (hasImage)
                Positioned.fill(
                  child: _buildBackgroundImage(imageUrl),
                ),
              
              // Light overlay for text readability
              if (hasImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                ),

              // Content
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Column(
                    children: [
                      // Top bar with close button (HIDDEN for force update)
                      if (canDismiss)
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close,
                                color: hasImage || isDarkBg ? Colors.white : Colors.black,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      
                      // Spacer to push content down
                      const Spacer(),

                      // Main content at bottom
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title
                            if (title != null && title.isNotEmpty)
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: (style['title_size'] ?? 28).toDouble(),
                                  fontWeight: FontWeight.bold,
                                  color: _parseColor(config['title_color']) ?? _parseColor(style['title_color']) ?? (hasImage || isDarkBg ? Colors.white : Colors.black),
                                ),
                              ),
                            if (title != null && title.isNotEmpty) const SizedBox(height: 16),

                            // Message
                            if (message != null && message.isNotEmpty)
                              Text(
                                message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: (style['message_size'] ?? 18).toDouble(),
                                  color: _parseColor(config['message_color']) ?? _parseColor(style['message_color']) ?? (hasImage || isDarkBg ? Colors.grey.shade300 : Colors.grey.shade600),
                                  height: 1.6,
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Bottom buttons
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          16,
                          24,
                          MediaQuery.of(context).padding.bottom + 24,
                        ),
                        child: _buildButtons(context, config['buttons'], style, config),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============ SHARED WIDGETS ============
Widget _buildImage(String imageUrl, double height) {
  if (imageUrl.startsWith('assets')) {
    return Image.asset(
      imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
      ),
    );
  } else {
    return Image.network(
      imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
      ),
    );
  }
}

Widget _buildButtons(BuildContext context, List<dynamic>? buttons, Map<String, dynamic> style, [Map<String, dynamic>? config]) {
  if (buttons == null || buttons.isEmpty) return const SizedBox.shrink();

  // Get global button colors from config (admin dashboard settings)
  final globalBtnColor = _parseColor(config?['button_color']);
  final globalBtnTextColor = _parseColor(config?['button_text_color']);

  return Column(
    children: List<Widget>.generate(buttons.length, (index) {
      final btn = buttons[index];
      final isOutlined = btn['outlined'] == true;
      // Priority: individual button color > global config color > default purple
      final btnColor = _parseColor(btn['color']) ?? globalBtnColor ?? Colors.deepPurple;
      final btnTextColor = globalBtnTextColor ?? Colors.white;
      // Support both 'text' and 'label' keys for button text
      final buttonText = btn['text'] ?? btn['label'] ?? 'Action';

      debugPrint('🔘 Button[$index]: text=$buttonText, action=${btn['action']}, target=${btn['target']}');

      return Padding(
        padding: EdgeInsets.only(bottom: index < buttons.length - 1 ? 12 : 0),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: isOutlined
              ? OutlinedButton(
                  onPressed: () {
                    debugPrint('🔘 Button CLICKED! action=${btn['action']}, target=${btn['target']}');
                    _handleAction(context, btn['action'], btn['target'], config: config);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: btnColor,
                    side: BorderSide(color: btnColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )
              : ElevatedButton(
                  onPressed: () {
                    debugPrint('🔘 Button CLICKED! action=${btn['action']}, target=${btn['target']}');
                    _handleAction(context, btn['action'], btn['target'], config: config);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnColor,
                    foregroundColor: btnTextColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
      );
    }),
  );
}

// Legacy class for backward compatibility
class DynamicPopupScreen extends StatelessWidget {
  final Map<String, dynamic> config;

  const DynamicPopupScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final displayType = _parseDisplayType(config['display_type'] ?? 'popup');
    
    if (displayType == PopupDisplayType.fullScreen) {
      return _FullScreenPopup(config: config);
    }
    return _CenterPopup(config: config);
  }
}
