import 'package:flutter/material.dart';

/// Server signal strength indicator widget
/// Shows 3 bars with different colors based on server load/connections:
/// - Green (3 bars): Low load (< 50 users) - Excellent
/// - Yellow (2 bars): Medium load (50-100 users) - Good
/// - Red (1 bar): High load (> 100 users) - Poor
class ServerSignalIndicator extends StatelessWidget {
  /// Total number of connections on the server
  final int totalConnections;
  
  /// Whether the server is currently connected (affects color brightness)
  final bool isConnected;
  
  /// Size of the indicator
  final double size;

  const ServerSignalIndicator({
    super.key,
    required this.totalConnections,
    this.isConnected = false,
    this.size = 18,
  });

  /// Determine signal level based on connections:
  /// - 0-49 users: 3 (excellent)
  /// - 50-99 users: 2 (good)
  /// - 100+ users: 1 (poor)
  int get signalLevel {
    if (totalConnections < 50) return 3;  // Low load - excellent
    if (totalConnections < 100) return 2; // Medium load - good
    return 1; // High load - poor
  }

  /// Get color based on signal level
  Color get signalColor {
    switch (signalLevel) {
      case 3:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 1:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = size * 0.2;
    final spacing = size * 0.1;
    final heights = [size * 0.4, size * 0.65, size * 1.0]; // Bar heights
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (index) {
        final isActive = (index + 1) <= signalLevel;
        final barColor = isActive 
            ? (isConnected ? signalColor : signalColor.withOpacity(0.8))
            : Colors.grey.shade300;
        
        return Container(
          width: barWidth,
          height: heights[index],
          margin: EdgeInsets.only(right: index < 2 ? spacing : 0),
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(barWidth / 2),
          ),
        );
      }),
    );
  }
}

/// Server signal indicator for location selection screen (larger size)
class ServerSignalIndicatorLarge extends StatelessWidget {
  final int totalConnections;
  final bool showLabel;

  const ServerSignalIndicatorLarge({
    super.key,
    required this.totalConnections,
    this.showLabel = false,
  });

  int get signalLevel {
    if (totalConnections < 50) return 3;
    if (totalConnections < 100) return 2;
    return 1;
  }

  Color get signalColor {
    switch (signalLevel) {
      case 3:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 1:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get loadLabel {
    switch (signalLevel) {
      case 3:
        return 'Low';
      case 2:
        return 'Medium';
      case 1:
        return 'High';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    const double size = 20;
    const double barWidth = 4;
    const double spacing = 2;
    final heights = [8.0, 13.0, 20.0];
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (index) {
            final isActive = (index + 1) <= signalLevel;
            final barColor = isActive ? signalColor : Colors.grey.shade300;
            
            return Container(
              width: barWidth,
              height: heights[index],
              margin: EdgeInsets.only(right: index < 2 ? spacing : 0),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(barWidth / 2),
              ),
            );
          }),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            loadLabel,
            style: TextStyle(
              fontSize: 11,
              color: signalColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Static version for when we don't have connection data
/// Uses status string ('online', 'maintenance', 'offline') instead
class ServerStatusIndicator extends StatelessWidget {
  final String status;
  final double size;

  const ServerStatusIndicator({
    super.key,
    required this.status,
    this.size = 18,
  });

  int get signalLevel {
    switch (status.toLowerCase()) {
      case 'online':
        return 3;
      case 'maintenance':
        return 2;
      case 'offline':
        return 1;
      default:
        return 3;
    }
  }

  Color get signalColor {
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = size * 0.2;
    final spacing = size * 0.1;
    final heights = [size * 0.4, size * 0.65, size * 1.0];
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (index) {
        final isActive = (index + 1) <= signalLevel;
        final barColor = isActive ? signalColor : Colors.grey.shade300;
        
        return Container(
          width: barWidth,
          height: heights[index],
          margin: EdgeInsets.only(right: index < 2 ? spacing : 0),
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(barWidth / 2),
          ),
        );
      }),
    );
  }
}

