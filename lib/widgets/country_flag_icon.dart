import 'package:flutter/material.dart';

/// Country flag icon widget that displays flag images instead of emojis
/// Uses country code (e.g., 'US', 'SG', 'JP') to show the appropriate flag
class CountryFlagIcon extends StatelessWidget {
  final String countryCode;
  final double size;
  final BoxShape shape;
  final bool showBorder;

  const CountryFlagIcon({
    super.key,
    required this.countryCode,
    this.size = 36,
    this.shape = BoxShape.circle,
    this.showBorder = true,
  });

  /// Map country code to flag image URL (using flagcdn.com)
  String get flagUrl {
    final code = countryCode.toLowerCase();
    // Use flagcdn.com which provides free flag images
    return 'https://flagcdn.com/w80/$code.png';
  }

  /// Fallback emoji if image fails
  String get fallbackEmoji {
    // Convert country code to emoji flag
    if (countryCode.length != 2) return '🌍';
    final code = countryCode.toUpperCase();
    final firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCodes([firstLetter, secondLetter]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: shape,
        border: showBorder
            ? Border.all(
                color: Colors.grey.shade300,
                width: 1,
              )
            : null,
        color: Colors.grey.shade100,
      ),
      child: ClipOval(
        child: Image.network(
          flagUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: size * 0.5,
                height: size * 0.5,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            // Fallback to emoji if image fails
            return Center(
              child: Text(
                fallbackEmoji,
                style: TextStyle(fontSize: size * 0.5),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Small inline flag icon for use in text rows
class CountryFlagIconSmall extends StatelessWidget {
  final String countryCode;
  final double size;

  const CountryFlagIconSmall({
    super.key,
    required this.countryCode,
    this.size = 24,
  });

  String get flagUrl {
    final code = countryCode.toLowerCase();
    return 'https://flagcdn.com/w40/$code.png';
  }

  String get fallbackEmoji {
    if (countryCode.length != 2) return '🌍';
    final code = countryCode.toUpperCase();
    final firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCodes([firstLetter, secondLetter]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
        color: Colors.white,
      ),
      child: ClipOval(
        child: Image.network(
          flagUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                fallbackEmoji,
                style: TextStyle(fontSize: size * 0.5),
              ),
            );
          },
        ),
      ),
    );
  }
}

