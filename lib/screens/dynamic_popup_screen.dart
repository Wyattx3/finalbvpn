import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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

Color? _parseColor(String? hexString) {
  if (hexString == null) return null;
  try {
    return Color(int.parse(hexString.replaceFirst('#', '0xFF')));
  } catch (e) {
    return null;
  }
}

void _handleAction(BuildContext context, String? action, String? target) async {
  if (action == null) return;

  switch (action) {
    case 'close':
      Navigator.pop(context);
      break;
    case 'link':
      if (target != null) {
        final Uri url = Uri.parse(target);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      }
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
  }
}

/// ============ CENTER POPUP (Dialog) ============
class _CenterPopup extends StatelessWidget {
  final Map<String, dynamic> config;

  const _CenterPopup({required this.config});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> style = config['style'] ?? {};
    final backgroundColor = _parseColor(style['background_color']) ?? Colors.white;
    final bool isDarkBg = backgroundColor.computeLuminance() < 0.5;
    final bool isDismissible = config['is_dismissible'] ?? true;

    return WillPopScope(
      onWillPop: () async => isDismissible,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: backgroundColor,
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close button (top right)
                  if (isDismissible)
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: isDarkBg ? Colors.white70 : Colors.grey,
                        ),
                      ),
                    ),

                  // Image
                  if (config['image_url'] != null)
                    _buildImage(config['image_url'], (config['image_height'] ?? 180).toDouble()),

                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      children: [
                        // Title
                        if (config['title'] != null)
                          Text(
                            config['title'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: (style['title_size'] ?? 22).toDouble(),
                              fontWeight: FontWeight.bold,
                              color: _parseColor(style['title_color']) ?? (isDarkBg ? Colors.white : Colors.black),
                            ),
                          ),
                        if (config['title'] != null) const SizedBox(height: 12),

                        // Message
                        if (config['message'] != null)
                          Text(
                            config['message'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: (style['message_size'] ?? 15).toDouble(),
                              color: _parseColor(style['message_color']) ?? (isDarkBg ? Colors.grey.shade300 : Colors.grey.shade600),
                              height: 1.5,
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Buttons
                        _buildButtons(context, config['buttons'], style),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ============ BOTTOM SHEET POPUP ============
class _BottomSheetPopup extends StatelessWidget {
  final Map<String, dynamic> config;

  const _BottomSheetPopup({required this.config});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> style = config['style'] ?? {};
    final backgroundColor = _parseColor(style['background_color']) ?? Colors.white;
    final bool isDarkBg = backgroundColor.computeLuminance() < 0.5;
    final bool isDismissible = config['is_dismissible'] ?? true;

    return WillPopScope(
      onWillPop: () async => isDismissible,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkBg ? Colors.grey.shade600 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Close button (top right)
                if (isDismissible)
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: isDarkBg ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ),

                // Image
                if (config['image_url'] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildImage(config['image_url'], (config['image_height'] ?? 180).toDouble()),
                    ),
                  ),

                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    children: [
                      // Title
                      if (config['title'] != null)
                        Text(
                          config['title'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: (style['title_size'] ?? 22).toDouble(),
                            fontWeight: FontWeight.bold,
                            color: _parseColor(style['title_color']) ?? (isDarkBg ? Colors.white : Colors.black),
                          ),
                        ),
                      if (config['title'] != null) const SizedBox(height: 12),

                      // Message
                      if (config['message'] != null)
                        Text(
                          config['message'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: (style['message_size'] ?? 15).toDouble(),
                            color: _parseColor(style['message_color']) ?? (isDarkBg ? Colors.grey.shade300 : Colors.grey.shade600),
                            height: 1.5,
                          ),
                        ),

                      const SizedBox(height: 28),

                      // Buttons
                      _buildButtons(context, config['buttons'], style),
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

/// ============ FULL SCREEN POPUP ============
class _FullScreenPopup extends StatelessWidget {
  final Map<String, dynamic> config;

  const _FullScreenPopup({required this.config});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> style = config['style'] ?? {};
    final backgroundColor = _parseColor(style['background_color']) ?? Colors.white;
    final bool isDarkBg = backgroundColor.computeLuminance() < 0.5;
    final bool isDismissible = config['is_dismissible'] ?? true;

    return WillPopScope(
      onWillPop: () async => isDismissible,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: backgroundColor,
          statusBarIconBrightness: isDarkBg ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: backgroundColor,
          systemNavigationBarIconBrightness: isDarkBg ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Top bar with close button
                if (isDismissible)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: isDarkBg ? Colors.white : Colors.black,
                          size: 28,
                        ),
                      ),
                    ),
                  ),

                // Main content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Image
                          if (config['image_url'] != null)
                            _buildImage(config['image_url'], (config['image_height'] ?? 200).toDouble()),

                          const SizedBox(height: 32),

                          // Title
                          if (config['title'] != null)
                            Text(
                              config['title'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: (style['title_size'] ?? 28).toDouble(),
                                fontWeight: FontWeight.bold,
                                color: _parseColor(style['title_color']) ?? (isDarkBg ? Colors.white : Colors.black),
                              ),
                            ),
                          if (config['title'] != null) const SizedBox(height: 16),

                          // Message
                          if (config['message'] != null)
                            Text(
                              config['message'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: (style['message_size'] ?? 18).toDouble(),
                                color: _parseColor(style['message_color']) ?? (isDarkBg ? Colors.grey.shade300 : Colors.grey.shade600),
                                height: 1.6,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom buttons
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    16,
                    24,
                    MediaQuery.of(context).padding.bottom + 24,
                  ),
                  child: _buildButtons(context, config['buttons'], style),
                ),
              ],
            ),
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

Widget _buildButtons(BuildContext context, List<dynamic>? buttons, Map<String, dynamic> style) {
  if (buttons == null || buttons.isEmpty) return const SizedBox.shrink();

  return Column(
    children: List<Widget>.generate(buttons.length, (index) {
      final btn = buttons[index];
      final isOutlined = btn['outlined'] == true;
      final btnColor = _parseColor(btn['color']) ?? Colors.deepPurple;

      return Padding(
        padding: EdgeInsets.only(bottom: index < buttons.length - 1 ? 12 : 0),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: isOutlined
              ? OutlinedButton(
                  onPressed: () => _handleAction(context, btn['action'], btn['target']),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: btnColor,
                    side: BorderSide(color: btnColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    btn['label'] ?? 'Action',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )
              : ElevatedButton(
                  onPressed: () => _handleAction(context, btn['action'], btn['target']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    btn['label'] ?? 'Action',
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
