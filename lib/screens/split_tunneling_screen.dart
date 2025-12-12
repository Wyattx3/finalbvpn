import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart' as device;
import 'app_selection_screen.dart' as my_app;
import '../user_manager.dart';
import '../services/sdui_service.dart';
import '../services/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';

class SplitTunnelingScreen extends StatefulWidget {
  const SplitTunnelingScreen({super.key});

  @override
  State<SplitTunnelingScreen> createState() => _SplitTunnelingScreenState();
}

class _SplitTunnelingScreenState extends State<SplitTunnelingScreen> {
  final UserManager _userManager = UserManager();
  final SduiService _sduiService = SduiService();
  final LocalizationService _l = LocalizationService();
  late int _selectedOption;

  List<my_app.AppInfo> _selectedAppsForUsesVPN = [];
  List<my_app.AppInfo> _selectedAppsForBypassVPN = [];
  List<my_app.AppInfo> _installedApps = [];

  // SDUI Config
  Map<String, dynamic> _config = {};
  List<Map<String, dynamic>> _options = [];
  bool _isLoading = true;

  // Default options (fallback if SDUI fails)
  static const List<Map<String, dynamic>> _defaultOptions = [
    {
      'index': 0,
      'icon': 'call_split',
      'title': 'Disable Split Tunneling',
      'subtitle': 'All apps use VPN connection',
    },
    {
      'index': 1,
      'icon': 'filter_list',
      'title': 'Only Selected Apps Use VPN',
      'subtitle': 'Choose specific apps to route through VPN',
    },
    {
      'index': 2,
      'icon': 'block',
      'title': 'Bypass VPN for Selected Apps',
      'subtitle': 'Selected apps will use direct connection',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedOption = _userManager.splitTunnelingMode.value;
    _loadSavedApps();
    _loadServerConfig();
    // Preload installed apps in background
    _fetchInstalledApps();
  }

  Future<void> _loadSavedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load apps for Uses VPN mode
      final usesVpnJson = prefs.getString('split_tunneling_uses_vpn');
      if (usesVpnJson != null) {
        final List<dynamic> decoded = jsonDecode(usesVpnJson);
        _selectedAppsForUsesVPN = decoded.map((e) => my_app.AppInfo(
          e['name'] ?? '',
          e['packageName'] ?? '',
          null, // Icon will be loaded later
          isSystemApp: e['isSystemApp'] ?? false,
        )).toList();
      }
      
      // Load apps for Bypass VPN mode
      final bypassVpnJson = prefs.getString('split_tunneling_bypass_vpn');
      if (bypassVpnJson != null) {
        final List<dynamic> decoded = jsonDecode(bypassVpnJson);
        _selectedAppsForBypassVPN = decoded.map((e) => my_app.AppInfo(
          e['name'] ?? '',
          e['packageName'] ?? '',
          null,
          isSystemApp: e['isSystemApp'] ?? false,
        )).toList();
      }
      
      debugPrint('📱 Loaded ${_selectedAppsForUsesVPN.length} apps for Uses VPN');
      debugPrint('📱 Loaded ${_selectedAppsForBypassVPN.length} apps for Bypass VPN');
    } catch (e) {
      debugPrint('❌ Error loading saved apps: $e');
    }
  }

  Future<void> _saveSelectedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save apps for Uses VPN mode
      final usesVpnData = _selectedAppsForUsesVPN.map((app) => {
        'name': app.name,
        'packageName': app.packageName,
        'isSystemApp': app.isSystemApp,
      }).toList();
      await prefs.setString('split_tunneling_uses_vpn', jsonEncode(usesVpnData));
      
      // Save apps for Bypass VPN mode
      final bypassVpnData = _selectedAppsForBypassVPN.map((app) => {
        'name': app.name,
        'packageName': app.packageName,
        'isSystemApp': app.isSystemApp,
      }).toList();
      await prefs.setString('split_tunneling_bypass_vpn', jsonEncode(bypassVpnData));
      
      // Also save to UserManager for VPN connection
      _userManager.setSplitTunnelingApps(
        usesVpnApps: _selectedAppsForUsesVPN.map((e) => e.packageName).toList(),
        bypassVpnApps: _selectedAppsForBypassVPN.map((e) => e.packageName).toList(),
      );
      
      debugPrint('✅ Saved split tunneling apps');
    } catch (e) {
      debugPrint('❌ Error saving apps: $e');
    }
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('split_tunneling');
      if (mounted) {
        if (response.containsKey('config') && response['config']['options'] != null) {
          setState(() {
            _config = response['config'];
            _options = List<Map<String, dynamic>>.from(_config['options'] ?? []);
            _isLoading = false;
          });
        } else {
          // Use default options
          setState(() {
            _options = List<Map<String, dynamic>>.from(_defaultOptions);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("SDUI Error: $e");
      // Use default options on error
      if (mounted) {
        setState(() {
          _options = List<Map<String, dynamic>>.from(_defaultOptions);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchInstalledApps() async {
    if (_installedApps.isNotEmpty) return;

    try {
      // First, load apps without icons (much faster)
      List<device.AppInfo> apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        withIcon: false, // Load without icons first for faster initial load
      );

      if (mounted) {
        setState(() {
          _installedApps = apps
              .map((app) => my_app.AppInfo(
                    app.name ?? '',
                    app.packageName ?? '',
                    null, // Icons will be loaded lazily
                    isSystemApp: false,
                  ))
              .toList();
          
          _installedApps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        });
        
        // Load icons asynchronously in background after UI is shown
        _loadAppIconsInBackground();
      }
    } catch (e) {
      debugPrint("Error fetching apps: $e");
    }
  }

  Future<void> _loadAppIconsInBackground() async {
    try {
      // Load all apps with icons in background (non-blocking)
      // This allows UI to show immediately while icons load
      List<device.AppInfo> appsWithIcons = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        withIcon: true,
      );

      if (!mounted) return;

      // Create a map for quick lookup
      final iconMap = <String, Uint8List?>{};
      for (var app in appsWithIcons) {
        iconMap[app.packageName ?? ''] = app.icon;
      }

      // Update icons in the existing list
      setState(() {
        _installedApps = _installedApps.map((app) {
          final icon = iconMap[app.packageName];
          if (icon != null) {
            return my_app.AppInfo(
              app.name,
              app.packageName,
              icon,
              isSystemApp: app.isSystemApp,
            );
          }
          return app;
        }).toList();
        
        // Also update icons for saved apps
        _selectedAppsForUsesVPN = _selectedAppsForUsesVPN.map((app) {
          final icon = iconMap[app.packageName];
          if (icon != null) {
            return my_app.AppInfo(app.name, app.packageName, icon, isSystemApp: app.isSystemApp);
          }
          return app;
        }).toList();
        
        _selectedAppsForBypassVPN = _selectedAppsForBypassVPN.map((app) {
          final icon = iconMap[app.packageName];
          if (icon != null) {
            return my_app.AppInfo(app.name, app.packageName, icon, isSystemApp: app.isSystemApp);
          }
          return app;
        }).toList();
      });
    } catch (e) {
      debugPrint("Error loading app icons: $e");
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'call_split':
        return Icons.call_split;
      case 'filter_list':
        return Icons.filter_list;
      case 'block':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);
    final textColor = isDark ? Colors.white : Colors.black;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: backgroundColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(_l.tr('split_tunneling')),
          centerTitle: true,
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          titleTextStyle: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Split tunneling allows you to choose which apps use VPN',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Options
              ..._options.map((option) {
              final index = option['index'] ?? 0;
              final icon = _getIconData(option['icon'] ?? '');
                final title = _sduiService.getText(option['title'], '');
                final subtitle = _sduiService.getText(option['subtitle'], '');
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildOption(
                  index: index,
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  showAppsCount: _selectedOption == index && index != 0,
                  selectedCount: index == 1 ? _selectedAppsForUsesVPN.length : _selectedAppsForBypassVPN.length,
                  onTapApps: () => _openAppSelection(index == 1),
                ),
              );
              }),
              
              const SizedBox(height: 20),
              
              // Current Status
              if (_selectedOption != 0) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.deepPurple.withOpacity(0.2) : Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _selectedOption == 1 ? Icons.filter_list : Icons.block,
                            color: Colors.deepPurple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Current Configuration',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedOption == 1
                            ? '${_selectedAppsForUsesVPN.length} apps will use VPN'
                            : '${_selectedAppsForBypassVPN.length} apps will bypass VPN',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAppSelection(bool isUsesVPN) async {
    if (!mounted) return;
    
    // Navigate directly - AppSelectionScreen will show skeleton and load apps itself
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => my_app.AppSelectionScreen(
          title: isUsesVPN ? 'Select Apps to Use VPN' : 'Select Apps to Bypass VPN',
          allApps: _installedApps, // May be empty - AppSelectionScreen will handle it
          selectedApps: isUsesVPN ? _selectedAppsForUsesVPN : _selectedAppsForBypassVPN,
        ),
      ),
    );

    if (result != null && result is List<my_app.AppInfo>) {
      setState(() {
        if (isUsesVPN) {
          _selectedAppsForUsesVPN = result;
        } else {
          _selectedAppsForBypassVPN = result;
        }
        
        // Also update _installedApps with the latest icons from result
        for (var resultApp in result) {
          if (resultApp.icon != null) {
            final index = _installedApps.indexWhere((a) => a.packageName == resultApp.packageName);
            if (index >= 0) {
              _installedApps[index] = resultApp;
            }
          }
        }
      });
      
      // Save the selection
      await _saveSelectedApps();
    }
  }

  Widget _buildOption({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    bool showAppsCount = false,
    int selectedCount = 0,
    VoidCallback? onTapApps,
  }) {
    final isSelected = _selectedOption == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF352F44) : Colors.white;
    final labels = _config['labels'] ?? {};

    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedOption = index;
        });
        _userManager.splitTunnelingMode.value = index;
        
        // Save mode to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('split_tunneling_mode', index);
        
        _saveSelectedApps(); // Save when mode changes
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: Colors.deepPurple, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.deepPurple.withOpacity(0.15)
                          : (isDark ? Colors.grey.withOpacity(0.1) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon, 
                      color: isSelected ? Colors.deepPurple : (isDark ? Colors.grey : Colors.black54),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.deepPurple : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? Colors.deepPurple : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
            if (showAppsCount) ...[
              Divider(height: 1, color: isDark ? Colors.black12 : Colors.grey.shade200),
              InkWell(
                onTap: onTapApps,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.apps, size: 18, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      Text(
                        '$selectedCount ${labels['selected_apps'] ?? 'apps selected'}',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap to edit',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
