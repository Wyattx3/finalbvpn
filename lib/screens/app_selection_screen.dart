import 'dart:typed_data';
import 'package:flutter/material.dart';
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
  late List<AppInfo> _selectedApps;
  late List<AppInfo> _allApps;
  String _searchQuery = '';

  // SDUI Config
  Map<String, dynamic> _labels = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedApps = List.from(widget.selectedApps);
    _allApps = widget.allApps;
    _loadServerConfig();
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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

                if (_selectedApps.isNotEmpty) ...[
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
                              _selectedApps.clear();
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
                                          _selectedApps.remove(app);
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
                  child: ListView.builder(
                    itemCount: filteredApps.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      final isSelected = _selectedApps.any((element) => element.packageName == app.packageName);

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
                                _selectedApps.add(app);
                              } else {
                                _selectedApps.removeWhere((element) => element.packageName == app.packageName);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            if (!isSelected) {
                              _selectedApps.add(app);
                            } else {
                              _selectedApps.removeWhere((element) => element.packageName == app.packageName);
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
}
