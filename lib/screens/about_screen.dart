import 'package:flutter/material.dart';
import '../services/sdui_service.dart';
import '../utils/message_dialog.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final SduiService _sduiService = SduiService();
  Map<String, dynamic> _config = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('about');
      if (mounted) {
        if (response.containsKey('config')) {
          setState(() {
            _config = response['config'];
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final backgroundColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);
    final primaryBlue = const Color(0xFF2196F3); // Match logo color

    final appName = _config['app_name'] ?? 'Suf Fhoke VPN';
    final version = _config['version'] ?? '1.0.1';
    final description = _config['description'] ?? 'Secure & Private VPN';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: Text(_config['title'] ?? 'About', style: TextStyle(color: textColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(flex: 1),
              
              // App Logo - Using actual app icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                appName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Version $version',
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  description,
                  style: TextStyle(color: subtitleColor),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Check for Updates Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showMessageDialog(
                      context,
                      message: 'You already have the latest version!',
                      type: MessageType.success,
                      title: 'Up to Date',
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check for Updates'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBlue,
                    side: BorderSide(color: primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Credits
              Text(
                'Made with ❤️ by $appName Team',
                style: TextStyle(color: subtitleColor),
              ),
              const SizedBox(height: 8),
              Text(
                '© 2025 $appName. All rights reserved.',
                style: TextStyle(color: subtitleColor, fontSize: 12),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
