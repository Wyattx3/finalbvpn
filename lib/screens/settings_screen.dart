import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme_notifier.dart';
import 'split_tunneling_screen.dart';
import 'vpn_protocol_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool displayLatency = true;
  bool enableDebugLog = false;
  bool pushSetting = true;
  
  void _showNotImplemented(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature feature is coming soon!'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, currentThemeMode, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
          final textColor = isDark ? Colors.white : Colors.black;
          final iconColor = isDark ? Colors.grey : Colors.black54;

          return ListView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 20, // Add bottom padding for system bar
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
                        '19a070***04eef7',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: '19a070***04eef7'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ID copied to clipboard')),
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
                trailing: CupertinoSwitch(
                  value: displayLatency,
                  activeColor: Colors.deepPurple,
                  trackColor: isDark ? Colors.grey.shade800 : null,
                  onChanged: (v) => setState(() => displayLatency = v),
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
                       onPressed: () => _showNotImplemented('Upload Log'), 
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
                onTap: () => _showNotImplemented('Language Selection'),
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
                onTap: () => _showNotImplemented('Privacy Policy'),
              ),
              _buildSettingItem(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onTap: () => _showNotImplemented('Terms of Service'),
              ),
              _buildSettingItem(
                icon: Icons.mail_outline,
                title: 'Contact Us',
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onTap: () => _showNotImplemented('Contact Support'),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('Other'),
              _buildSettingItem(
                icon: Icons.share_outlined,
                title: 'Share',
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onTap: () => _showNotImplemented('Share'),
              ),
              InkWell(
                onTap: () => _showNotImplemented('Version Info'),
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
                        'V1.0.8 (latest)',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      ),
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
