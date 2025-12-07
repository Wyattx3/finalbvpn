import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart' as device;
import 'app_selection_screen.dart' as my_app;
import '../user_manager.dart';
import '../services/sdui_service.dart';

class SplitTunnelingScreen extends StatefulWidget {
  const SplitTunnelingScreen({super.key});

  @override
  State<SplitTunnelingScreen> createState() => _SplitTunnelingScreenState();
}

class _SplitTunnelingScreenState extends State<SplitTunnelingScreen> {
  final UserManager _userManager = UserManager();
  final SduiService _sduiService = SduiService();
  late int _selectedOption;

  List<my_app.AppInfo> _selectedAppsForUsesVPN = [];
  List<my_app.AppInfo> _selectedAppsForBypassVPN = [];
  List<my_app.AppInfo> _installedApps = [];

  // SDUI Config
  Map<String, dynamic> _config = {};
  List<Map<String, dynamic>> _options = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedOption = _userManager.splitTunnelingMode.value;
    _loadServerConfig();
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('split_tunneling');
      if (mounted) {
        if (response.containsKey('config')) {
          setState(() {
            _config = response['config'];
            _options = List<Map<String, dynamic>>.from(_config['options'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint("SDUI Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchInstalledApps() async {
    if (_installedApps.isNotEmpty) return;

    try {
      // excludeSystemApps: false (include system apps), withIcon: true
      List<device.AppInfo> apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        withIcon: true,
      );

      if (mounted) {
        setState(() {
          _installedApps = apps
              .map((app) => my_app.AppInfo(
                    app.name ?? '',
                    app.packageName ?? '',
                    app.icon,
                    isSystemApp: false, // InstalledApps pkg doesn't easily expose this
                  ))
              .toList();
          
          _installedApps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        });
      }
    } catch (e) {
      debugPrint("Error fetching apps: $e");
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
          title: Text(_config['title'] ?? 'Split Tunneling'),
          centerTitle: true,
          backgroundColor: backgroundColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          titleTextStyle: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: _options.map((option) {
              final index = option['index'] ?? 0;
              final icon = _getIconData(option['icon'] ?? '');
              final title = option['title'] ?? '';
              final subtitle = option['subtitle'] ?? '';
              
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
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _openAppSelection(bool isUsesVPN) async {
    if (_installedApps.isEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await _fetchInstalledApps();
      if (mounted) Navigator.pop(context); // Close loading dialog
    }

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => my_app.AppSelectionScreen(
          title: isUsesVPN ? 'Uses VPN' : 'Bypass VPN',
          allApps: _installedApps,
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
      });
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
      onTap: () {
        setState(() {
          _selectedOption = index;
        });
        _userManager.splitTunnelingMode.value = index;
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: Colors.deepPurple.withOpacity(0.5), width: 1) : null,
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
                  Icon(icon, color: isSelected ? Colors.deepPurple : (isDark ? Colors.grey : Colors.black54)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
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
              Divider(height: 1, color: isDark ? Colors.black12 : Colors.grey.shade100),
              InkWell(
                onTap: onTapApps,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        '$selectedCount ${labels['selected_apps'] ?? 'Selected Applications'}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade500),
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
