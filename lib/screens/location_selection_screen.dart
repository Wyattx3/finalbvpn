import 'package:flutter/material.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  int selectedTabIndex = 0; // 0 for Universal, 1 for Streaming
  String selectedLocation = 'US - San Jose'; // Default selection

  final List<Map<String, dynamic>> universalLocations = [
    {
      'country': 'United States',
      'flag': '🇺🇸',
      'cities': [
        'US - San Jose',
        'US - Los Angeles',
        'US - New York',
        'US - Ashburn',
        'US - Virginia',
        'US - Miami',
        'US - Oregon',
        'US - Dallas',
      ]
    },
    {
      'country': 'Canada',
      'flag': '🇨🇦',
      'cities': [
        'CA - Vancouver',
        'CA - Toronto',
        'CA - Montreal',
      ]
    },
    {
      'country': 'United Kingdom',
      'flag': '🇬🇧',
      'cities': [
        'UK - London',
        'UK - Manchester',
      ]
    },
    {
      'country': 'Singapore',
      'flag': '🇸🇬',
      'cities': [
        'SG - Singapore',
      ]
    },
    {
      'country': 'Japan',
      'flag': '🇯🇵',
      'cities': [
        'JP - Tokyo',
        'JP - Osaka',
      ]
    },
  ];

  final List<Map<String, dynamic>> streamingLocations = [
    {
      'country': 'Netflix',
      'flag': '🎬',
      'cities': [
        'US - Netflix',
        'UK - Netflix',
        'JP - Netflix',
      ]
    },
     {
      'country': 'Disney+',
      'flag': '📺',
      'cities': [
        'US - Disney+',
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    final dataList = selectedTabIndex == 0 ? universalLocations : streamingLocations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
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
                    label: const Text('Universal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedTabIndex == 0 ? Colors.deepPurple : Colors.white,
                      foregroundColor: selectedTabIndex == 0 ? Colors.white : Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: selectedTabIndex == 0 ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
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
                      backgroundColor: selectedTabIndex == 1 ? Colors.deepPurple : Colors.white,
                      foregroundColor: selectedTabIndex == 1 ? Colors.white : Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: selectedTabIndex == 1 ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
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
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 20, // Add bottom padding for system bar
              ),
              itemCount: dataList.length,
              itemBuilder: (context, index) {
                final country = dataList[index];
                return CountryTile(
                  countryName: country['country'],
                  flagEmoji: country['flag'],
                  locations: List<String>.from(country['cities']),
                  selectedLocation: selectedLocation,
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
    );
  }
}

class CountryTile extends StatelessWidget {
  final String countryName;
  final String flagEmoji;
  final List<String> locations;
  final String selectedLocation;
  final Function(String) onLocationSelected;

  const CountryTile({
    super.key,
    required this.countryName,
    required this.flagEmoji,
    required this.locations,
    required this.selectedLocation,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool isExpandedInitially = locations.contains(selectedLocation);

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
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
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
        children: locations.map((location) => _buildLocationItem(location)).toList(),
      ),
    );
  }

  Widget _buildLocationItem(String location) {
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
            color: isSelected ? Colors.deepPurple : Colors.grey.shade700,
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

