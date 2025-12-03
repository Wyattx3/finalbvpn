import 'package:flutter/material.dart';
import '../services/mock_sdui_service.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final MockSduiService _sduiService = MockSduiService();
  
  int selectedTabIndex = 0; // 0 for Universal, 1 for Streaming
  String selectedLocation = 'US - San Jose'; // Default selection
  
  // Data from SDUI
  List<Map<String, dynamic>> universalLocations = [];
  List<Map<String, dynamic>> streamingLocations = [];
  Map<String, dynamic> _config = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('location_selection');
      if (mounted) {
        if (response.containsKey('config')) {
          final config = response['config'];
          setState(() {
            _config = config;
            universalLocations = List<Map<String, dynamic>>.from(config['universal_locations'] ?? []);
            streamingLocations = List<Map<String, dynamic>>.from(config['streaming_locations'] ?? []);
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dataList = selectedTabIndex == 0 ? universalLocations : streamingLocations;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);
    final textColor = isDark ? Colors.white : Colors.black;
    
    // Tabs config
    final tabs = _config['tabs'] as List<dynamic>? ?? [];
    String tab1Label = "Universal";
    String tab2Label = "Streaming";
    if (tabs.isNotEmpty) {
      tab1Label = tabs[0]['label'] ?? "Universal";
      if (tabs.length > 1) tab2Label = tabs[1]['label'] ?? "Streaming";
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: Text(_config['title'] ?? 'Select Location', style: TextStyle(color: textColor)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tabs
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
                      label: Text(tab1Label),
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
                      label: Text(tab2Label),
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

            // List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 100),
                itemCount: dataList.length,
                itemBuilder: (context, index) {
                  final country = dataList[index];
                  return CountryTile(
                    countryName: country['country'],
                    flagEmoji: country['flag'],
                    locations: List<String>.from(country['cities']),
                    selectedLocation: selectedLocation,
                    isDark: isDark,
                    onLocationSelected: (loc) {
                      setState(() {
                        selectedLocation = loc;
                      });
                      // Return the selected location and flag back to previous screen
                      Navigator.pop(context, {'location': loc, 'flag': country['flag']});
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
  final String selectedLocation;
  final bool isDark;
  final Function(String) onLocationSelected;

  const CountryTile({
    super.key,
    required this.countryName,
    required this.flagEmoji,
    required this.locations,
    required this.selectedLocation,
    required this.isDark,
    required this.onLocationSelected,
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
        children: locations.map((location) => _buildLocationItem(location, textColor)).toList(),
      ),
    );
  }

  Widget _buildLocationItem(String location, Color textColor) {
    bool isSelected = location == selectedLocation;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.deepPurple.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: Colors.deepPurple)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(
          location,
          style: TextStyle(
            color: isSelected ? Colors.deepPurple : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Icon(Icons.signal_cellular_alt, color: Colors.green, size: 20),
             if (isSelected) ...[
               const SizedBox(width: 8),
               const Icon(Icons.check_circle, color: Colors.deepPurple, size: 20),
             ]
          ],
        ),
        onTap: () => onLocationSelected(location),
      ),
    );
  }
}
