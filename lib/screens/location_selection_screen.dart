import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/vpn_speed_service.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final VpnSpeedService _speedService = VpnSpeedService();
  
  int selectedTabIndex = 0; // 0 for Universal, 1 for Streaming
  String selectedLocation = '';
  
  // Servers grouped by country from Firebase
  Map<String, List<Map<String, dynamic>>> _universalLocations = {};
  Map<String, List<Map<String, dynamic>>> _streamingLocations = {};
  bool _isLoading = true;
  bool _isMeasuringPing = false;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() => _isLoading = true);
    
    try {
      final servers = await _firebaseService.getServers();
      
      if (mounted) {
        // Group servers by country for Universal tab
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var server in servers) {
          final country = server['country'] ?? 'Unknown';
          if (!grouped.containsKey(country)) {
            grouped[country] = [];
          }
          grouped[country]!.add(server);
        }
        
        setState(() {
          _universalLocations = grouped;
          _streamingLocations = grouped;
          _isLoading = false;
        });
        
        // Measure ping for all servers in background
        _measureAllPings(servers);
      }
    } catch (e) {
      debugPrint('Error loading servers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _measureAllPings(List<Map<String, dynamic>> servers) async {
    if (_isMeasuringPing) return;
    
    setState(() => _isMeasuringPing = true);
    
    for (var server in servers) {
      if (!mounted) break;
      
      final address = server['address'] as String?;
      if (address != null) {
        final ping = await _speedService.measurePing(address);
        
        if (mounted) {
          // Update server with ping value
          setState(() {
            // Find and update server in grouped maps
            for (var country in _universalLocations.keys) {
              for (var s in _universalLocations[country]!) {
                if (s['id'] == server['id']) {
                  s['latency'] = ping;
                }
              }
            }
          });
        }
      }
    }
    
    if (mounted) {
      setState(() => _isMeasuringPing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dataMap = selectedTabIndex == 0 ? _universalLocations : _streamingLocations;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: Text('Select Location', style: TextStyle(color: textColor)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tabs - Original Design
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedTabIndex = 0;
                        });
                      },
                      icon: const Icon(Icons.grid_view),
                      label: const Text('Universal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedTabIndex == 0 ? Colors.deepPurple : (isDark ? const Color(0xFF352F44) : Colors.white),
                        foregroundColor: selectedTabIndex == 0 ? Colors.white : textColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: selectedTabIndex == 0 ? BorderSide.none : BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedTabIndex = 1;
                        });
                      },
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Streaming'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedTabIndex == 1 ? Colors.deepPurple : (isDark ? const Color(0xFF352F44) : Colors.white),
                        foregroundColor: selectedTabIndex == 1 ? Colors.white : textColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: selectedTabIndex == 1 ? BorderSide.none : BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Region Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  selectedTabIndex == 0 ? 'All Locations' : 'Streaming Services',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // List grouped by country - Original Design
            Expanded(
              child: dataMap.isEmpty
                  ? const Center(child: Text('No servers available'))
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 100),
                      itemCount: dataMap.length,
                      itemBuilder: (context, index) {
                        final country = dataMap.keys.elementAt(index);
                        final servers = dataMap[country]!;
                        final flag = servers.first['flag'] ?? '🌍';
                        final cities = servers.map((s) => s['name'] as String).toList();
                        
                        return CountryTile(
                          countryName: country,
                          flagEmoji: flag,
                          locations: cities,
                          servers: servers,
                          selectedLocation: selectedLocation,
                          isDark: isDark,
                          onLocationSelected: (loc, server) {
                            setState(() {
                              selectedLocation = loc;
                            });
                            Navigator.pop(context, {
                              'location': '$country - $loc',
                              'flag': flag,
                              'server': server,
                            });
                          },
                          onMaintenanceServerTapped: (serverName) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$serverName is under maintenance. Please try another server.'),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class CountryTile extends StatelessWidget {
  final String countryName;
  final String flagEmoji;
  final List<String> locations;
  final List<Map<String, dynamic>> servers;
  final String selectedLocation;
  final bool isDark;
  final Function(String, Map<String, dynamic>) onLocationSelected;
  final Function(String) onMaintenanceServerTapped;

  const CountryTile({
    super.key,
    required this.countryName,
    required this.flagEmoji,
    required this.locations,
    required this.servers,
    required this.selectedLocation,
    required this.isDark,
    required this.onLocationSelected,
    required this.onMaintenanceServerTapped,
  });

  @override
  Widget build(BuildContext context) {
    final bool isExpandedInitially = locations.contains(selectedLocation);
    final textColor = isDark ? Colors.white : Colors.black;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: isExpandedInitially,
        leading: Text(
          flagEmoji,
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(
          countryName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: textColor,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_cellular_alt, color: Colors.green),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.grey.shade400,
            ),
          ],
        ),
        children: locations.asMap().entries.map((entry) {
          final index = entry.key;
          final location = entry.value;
          final server = servers[index];
          return _buildLocationItem(location, server, textColor);
        }).toList(),
      ),
    );
  }

  Widget _buildLocationItem(String location, Map<String, dynamic> server, Color textColor) {
    bool isSelected = location == selectedLocation;
    final latency = server['latency'] ?? 0;
    final status = server['status'] as String? ?? 'online';
    final isMaintenance = status == 'maintenance';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isMaintenance 
            ? Colors.orange.withOpacity(0.1)
            : isSelected 
                ? Colors.deepPurple.withOpacity(0.1) 
                : null,
        borderRadius: BorderRadius.circular(10),
        border: isMaintenance
            ? Border.all(color: Colors.orange.withOpacity(0.5))
            : isSelected
                ? Border.all(color: Colors.deepPurple)
                : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                location,
                style: TextStyle(
                  color: isMaintenance 
                      ? Colors.orange.shade700
                      : isSelected 
                          ? Colors.deepPurple 
                          : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isMaintenance) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Maintenance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMaintenance) ...[
              Text(
                '${latency}ms',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.signal_cellular_alt, color: Colors.green, size: 20),
            ] else ...[
              Icon(Icons.construction, color: Colors.orange.shade700, size: 20),
            ],
            if (isSelected && !isMaintenance) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: Colors.deepPurple, size: 20),
            ]
          ],
        ),
        onTap: isMaintenance 
            ? () => onMaintenanceServerTapped(location)
            : () => onLocationSelected(location, server),
      ),
    );
  }
}
