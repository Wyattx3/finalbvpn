import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../user_manager.dart';
import '../theme_notifier.dart';
import '../services/sdui_service.dart';
import '../services/firebase_service.dart';
import '../utils/message_dialog.dart';
import 'split_tunneling_screen.dart';
import 'vpn_protocol_screen.dart';
import 'language_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'contact_us_screen.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserManager _userManager = UserManager();
  final SduiService _sduiService = SduiService();
  final FirebaseService _firebaseService = FirebaseService();
  
  bool enableDebugLog = false;
  bool pushSetting = true;
  
  // SDUI Config
  Map<String, dynamic> _config = {};
  bool _isConfigLoading = true;
  bool _isDeviceIdLoading = true;
  StreamSubscription? _sduiSubscription;
  
  // Combined loading state - show spinner until both are loaded
  bool get _isLoading => _isConfigLoading || _isDeviceIdLoading;
  
  // Device ID for support
  String _deviceId = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
    _loadDeviceId();
  }

  @override
  void dispose() {
    _sduiSubscription?.cancel();
    super.dispose();
  }
  
  Future<void> _loadDeviceId() async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      debugPrint('📱 Settings loaded device ID: $deviceId');
      if (mounted) {
        setState(() {
          _deviceId = deviceId;
          _isDeviceIdLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading device ID: $e');
      if (mounted) {
        setState(() {
          _deviceId = 'Error loading ID';
          _isDeviceIdLoading = false;
        });
      }
    }
  }

  void _loadServerConfig() {
    debugPrint('⚙️ Settings: Starting real-time SDUI listener...');
    _sduiSubscription?.cancel();
    _sduiSubscription = _sduiService.watchScreenConfig('settings').listen(
      (response) {
        debugPrint('⚙️ Settings: Received SDUI update!');
        if (mounted) {
          if (response.containsKey('config')) {
            setState(() {
              _config = response['config'];
              _isConfigLoading = false;
            });
            debugPrint('✅ Settings: UI updated with real-time config');
          } else {
            setState(() => _isConfigLoading = false);
          }
        }
      },
      onError: (e) {
        debugPrint("❌ Settings SDUI Error: $e");
        if (mounted) setState(() => _isConfigLoading = false);
      },
    );
  }
  
  void _showNotImplemented(String feature) {
    showMessageDialog(
      context,
      message: '$feature feature is coming soon!',
      type: MessageType.info,
      title: 'Coming Soon',
    );
  }

  void _showShareDialog() {
    final shareText = _config['share_text'] ?? 'Check out Suf Fhoke VPN - Secure, Fast & Private VPN!\n\nDownload now: https://play.google.com/store/apps/details?id=com.example.vpn_app';
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Share Suf Fhoke VPN',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildShareOption(
                      icon: Icons.copy,
                      label: 'Copy Link',
                      color: Colors.blue,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: shareText));
                        Navigator.pop(ctx);
                        showMessageDialog(
                          context,
                          message: 'Link copied to clipboard!',
                          type: MessageType.success,
                          title: 'Copied',
                        );
                      },
                    ),
                    _buildShareOption(
                      icon: Icons.message,
                      label: 'Message',
                      color: Colors.green,
                      onTap: () {
                        Navigator.pop(ctx);
                        showMessageDialog(
                          context,
                          message: 'Opening Messages...',
                          type: MessageType.info,
                          title: 'Messages',
                        );
                      },
                    ),
                    _buildShareOption(
                      icon: Icons.email,
                      label: 'Email',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(ctx);
                        showMessageDialog(
                          context,
                          message: 'Opening Email...',
                          type: MessageType.info,
                          title: 'Email',
                        );
                      },
                    ),
                    _buildShareOption(
                      icon: Icons.more_horiz,
                      label: 'More',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(ctx);
                        showMessageDialog(
                          context,
                          message: 'Opening share options...',
                          type: MessageType.info,
                          title: 'Share',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    shareText,
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showUploadLogDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: Colors.deepPurple),
              SizedBox(width: 12),
              Text('Upload Debug Log'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will upload your debug logs to our server for troubleshooting purposes.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                'The log file contains:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('• Connection timestamps'),
              Text('• Error messages'),
              Text('• App performance data'),
              Text('• Device information'),
              SizedBox(height: 16),
              Text(
                'No personal browsing data is included.',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _uploadLog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
  }

  void _uploadLog() {
    // Show uploading progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.deepPurple),
              const SizedBox(height: 20),
              const Text('Uploading log file...'),
              const SizedBox(height: 8),
              Text(
                'Please wait',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );

    // Simulate upload delay
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context); // Close progress dialog
      
      // Show success dialog
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text('Upload Successful'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your debug log has been uploaded successfully.'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tag, size: 16, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      const Text(
                        'Reference ID: ',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'LOG-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please save this ID if you contact support.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Use actual device ID from Firebase, not config
    final accountId = _deviceId;
    final version = _config['version'] ?? 'V1.0.8 (latest)';

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentThemeMode, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;
        final iconColor = isDark ? Colors.grey : Colors.black54;
        final backgroundColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            // Status Bar
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            
            // Navigation Bar (Bottom Bar)
            systemNavigationBarColor: backgroundColor, // Matches theme background
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: Scaffold(
            appBar: AppBar(
              title: Text(_config['title'] ?? 'Settings'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: ListView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              children: [
                _buildSectionHeader('Account'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.smartphone, color: iconColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          accountId,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: accountId));
                          showMessageDialog(
                            context,
                            message: 'ID copied to clipboard',
                            type: MessageType.success,
                            title: 'Copied',
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Copy', style: TextStyle(color: Colors.grey)),
                              SizedBox(width: 4),
                              Icon(Icons.copy, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                _buildSectionHeader('VPN Settings'),
                _buildSettingItem(
                  icon: Icons.call_split,
                  title: 'Split Tunneling',
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Disable', style: TextStyle(color: Colors.grey)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SplitTunnelingScreen()),
                    );
                  },
                ),
                _buildSettingItem(
                  icon: Icons.security,
                  title: 'VPN Protocol',
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Auto', style: TextStyle(color: Colors.grey)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const VpnProtocolScreen()),
                    );
                  },
                ),
                _buildSettingItem(
                  icon: Icons.speed,
                  title: 'Display Latency',
                  trailing: ValueListenableBuilder<bool>(
                    valueListenable: _userManager.displayLatency,
                    builder: (context, value, child) {
                      return CupertinoSwitch(
                        value: value,
                        activeColor: Colors.deepPurple,
                        trackColor: isDark ? Colors.grey.shade800 : null,
                        onChanged: (v) => _userManager.displayLatency.value = v,
                      );
                    },
                  ),
                ),
                _buildSettingItem(
                  icon: Icons.bug_report_outlined,
                  title: 'Enable Debug Log',
                  trailing: CupertinoSwitch(
                    value: enableDebugLog,
                    activeColor: Colors.deepPurple,
                    trackColor: isDark ? Colors.grey.shade800 : null,
                    onChanged: (v) => setState(() => enableDebugLog = v),
                  ),
                ),
                if (enableDebugLog)
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0, left: 16, right: 16),
                     child: Align(
                       alignment: Alignment.centerRight,
                       child: TextButton.icon(
                         onPressed: () => _showUploadLogDialog(), 
                         icon: const Icon(Icons.upload_file, size: 16),
                         label: const Text('Upload Log'),
                       ),
                     ),
                   ),

                const SizedBox(height: 20),
                _buildSectionHeader('APP Settings'),
                _buildSettingItem(
                  icon: Icons.language,
                  title: 'Language',
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('English', style: TextStyle(color: Colors.grey)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LanguageScreen()),
                    );
                  },
                ),
                _buildSettingItem(
                  icon: Icons.notifications_none,
                  title: 'Push Setting',
                  trailing: CupertinoSwitch(
                    value: pushSetting,
                    activeColor: Colors.deepPurple,
                    trackColor: isDark ? Colors.grey.shade800 : null,
                    onChanged: (v) => setState(() => pushSetting = v),
                  ),
                ),
                _buildSettingItem(
                  icon: currentThemeMode == ThemeMode.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  title: 'Theme Mode',
                  trailing: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => themeNotifier.value = ThemeMode.light,
                          child: _buildThemeOption(Icons.light_mode, currentThemeMode == ThemeMode.light),
                        ),
                        InkWell(
                          onTap: () => themeNotifier.value = ThemeMode.dark,
                          child: _buildThemeOption(Icons.dark_mode, currentThemeMode == ThemeMode.dark),
                        ),
                        InkWell(
                          onTap: () => themeNotifier.value = ThemeMode.system,
                          child: _buildThemeOption(Icons.settings_brightness, currentThemeMode == ThemeMode.system),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                _buildSectionHeader('Support'),
                _buildSettingItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                    );
                  },
                ),
                _buildSettingItem(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
                    );
                  },
                ),
                _buildSettingItem(
                  icon: Icons.mail_outline,
                  title: 'Contact Us',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ContactUsScreen()),
                    );
                  },
                ),

                const SizedBox(height: 20),
                _buildSectionHeader('Other'),
                _buildSettingItem(
                  icon: Icons.share_outlined,
                  title: 'Share',
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    _showShareDialog();
                  },
                ),
                // Device ID for Support
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _deviceId));
                    showMessageDialog(
                      context,
                      message: 'Device ID copied!\n\n$_deviceId',
                      type: MessageType.success,
                      title: 'Copied',
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.fingerprint, color: Colors.grey),
                        const SizedBox(width: 12),
                        const Text(
                          'Device ID',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey
                          ),
                        ),
                        const Spacer(),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            _deviceId.length > 10 
                              ? '${_deviceId.substring(0, 6)}***${_deviceId.substring(_deviceId.length - 5)}'
                              : _deviceId,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AboutScreen()),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.grey),
                        const SizedBox(width: 12),
                        const Text(
                          'Version',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey
                          ),
                        ),
                        const Spacer(),
                        Text(
                          version,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.grey : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(IconData icon, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isSelected ? (isDark ? Colors.black : Colors.white) : Colors.transparent,
        shape: BoxShape.circle,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                )
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.deepPurple : Colors.grey,
      ),
    );
  }
}
