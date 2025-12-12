import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart' as device;
import '../services/sdui_service.dart';

class AppInfo {
  final String name;
  final String packageName;
  final Uint8List? icon; // Changed from IconData to Uint8List for real app icons
  final bool isSystemApp;

  AppInfo(this.name, this.packageName, this.icon, {this.isSystemApp = false});
}

class AppSelectionScreen extends StatefulWidget {
  final String title;
  final List<AppInfo> allApps;
  final List<AppInfo> selectedApps;

  const AppSelectionScreen({
    super.key,
    required this.title,
    required this.allApps,
    required this.selectedApps,
  });

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  final SduiService _sduiService = SduiService();
  late Set<String> _selectedPackageNames; // Track by package name for reliable comparison
  late List<AppInfo> _allApps;
  String _searchQuery = '';
  bool _isLoadingApps = false;

  // SDUI Config
  Map<String, dynamic> _labels = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use package names for reliable tracking (survives app list refresh)
    _selectedPackageNames = widget.selectedApps.map((e) => e.packageName).toSet();
    _allApps = List.from(widget.allApps);
    _loadServerConfig();
    
    // If apps list is empty, load apps here with skeleton
    if (_allApps.isEmpty) {
      _loadInstalledApps();
    }
  }
  
  /// Load installed apps if not provided
  Future<void> _loadInstalledApps() async {
    if (_isLoadingApps) return;
    _isLoadingApps = true;
    
    try {
      // Load apps without icons first (faster)
      List<device.AppInfo> apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        withIcon: false,
      );

      if (mounted) {
        setState(() {
          _allApps = apps
              .map((app) => AppInfo(
                    app.name ?? '',
                    app.packageName ?? '',
                    null,
                    isSystemApp: false,
                  ))
              .toList();
          _allApps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        });
        
        // Load icons in background
        _loadAppIconsInBackground();
      }
    } catch (e) {
      debugPrint("Error loading apps: $e");
    }
    
    _isLoadingApps = false;
  }
  
  /// Load app icons in background after list is shown
  Future<void> _loadAppIconsInBackground() async {
    try {
      List<device.AppInfo> appsWithIcons = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        withIcon: true,
      );

      if (!mounted) return;

      final iconMap = <String, Uint8List?>{};
      for (var app in appsWithIcons) {
        iconMap[app.packageName ?? ''] = app.icon;
      }

      setState(() {
        _allApps = _allApps.map((app) {
          final icon = iconMap[app.packageName];
          if (icon != null) {
            return AppInfo(app.name, app.packageName, icon, isSystemApp: app.isSystemApp);
          }
          return app;
        }).toList();
      });
    } catch (e) {
      debugPrint("Error loading icons: $e");
    }
  }
  
  // Get selected apps as AppInfo objects (for returning result)
  List<AppInfo> get _selectedApps {
    return _allApps.where((app) => _selectedPackageNames.contains(app.packageName)).toList();
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('app_selection');
      if (mounted) {
        if (response.containsKey('config')) {
          setState(() {
            _labels = Map<String, dynamic>.from(response['config']['labels'] ?? {});
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final backgroundColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);

    final filteredApps = _allApps.where((app) {
      return app.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: Text(widget.title, style: TextStyle(color: textColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context, _selectedApps),
        ),
      ),
      body: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    style: TextStyle(color: textColor),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search apps...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                      filled: true,
                      fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),

                if (_selectedPackageNames.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_sduiService.getText(_labels['selected'], 'Selected')} (${_selectedApps.length})',
                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedPackageNames.clear();
                            });
                          },
                          child: Text(_sduiService.getText(_labels['clear_all'], 'Clear All'), style: const TextStyle(color: Colors.deepPurple)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _selectedApps.length,
                      itemBuilder: (context, index) {
                        final app = _selectedApps[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  _buildAppIcon(app, size: 50),
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedPackageNames.remove(app.packageName);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.grey,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  app.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 10, color: textColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Divider(color: Colors.grey.withOpacity(0.2)),
                ],

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _sduiService.getText(_labels['select_applications'], 'Select Applications'),
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

                Expanded(
                  child: _allApps.isEmpty
                      ? _buildSkeletonList(isDark) // Show skeleton while loading
                      : ListView.builder(
                          itemCount: filteredApps.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final app = filteredApps[index];
                            final isSelected = _selectedPackageNames.contains(app.packageName);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: _buildAppIcon(app, size: 40),
                              title: Text(app.name, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                              subtitle: Text(app.packageName, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              trailing: Checkbox(
                                value: isSelected,
                                activeColor: Colors.deepPurple,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedPackageNames.add(app.packageName);
                                    } else {
                                      _selectedPackageNames.remove(app.packageName);
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  if (!isSelected) {
                                    _selectedPackageNames.add(app.packageName);
                                  } else {
                                    _selectedPackageNames.remove(app.packageName);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppIcon(AppInfo app, {required double size}) {
    if (app.icon != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          app.icon!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.android, color: Colors.grey.shade600, size: size * 0.6),
      );
    }
  }
  
  /// Build skeleton loading list for apps
  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      itemCount: 15, // Show 15 skeleton items
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Skeleton icon
              _buildSkeletonBox(40, 40, isDark, borderRadius: 8),
              const SizedBox(width: 16),
              // Skeleton text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSkeletonBox(double.infinity, 14, isDark, widthFactor: 0.6),
                    const SizedBox(height: 6),
                    _buildSkeletonBox(double.infinity, 10, isDark, widthFactor: 0.8),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Skeleton checkbox
              _buildSkeletonBox(24, 24, isDark, borderRadius: 4),
            ],
          ),
        );
      },
    );
  }
  
  /// Build a single skeleton box with shimmer effect
  Widget _buildSkeletonBox(double width, double height, bool isDark, {double? widthFactor, double borderRadius = 4}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: const _ShimmerEffect(),
      ),
    );
  }
}

/// Shimmer effect widget for skeleton loading
class _ShimmerEffect extends StatefulWidget {
  const _ShimmerEffect();

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: isDark
                  ? [Colors.grey.shade800, Colors.grey.shade700, Colors.grey.shade800]
                  : [Colors.grey.shade300, Colors.grey.shade200, Colors.grey.shade300],
            ),
          ),
        );
      },
    );
  }
}
