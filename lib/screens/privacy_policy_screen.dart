import 'package:flutter/material.dart';
import '../services/sdui_service.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
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
      final response = await _sduiService.getScreenConfig('privacy_policy');
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
    
    // Get content from config, with fallback to default content
    String content = _sduiService.getText(_config['content'], '');
    if (content.isEmpty || content == 'No content available.') {
      // Show default English content as immediate fallback
      content = """PRIVACY POLICY

Last updated: November 2025

1. INFORMATION WE COLLECT

We collect information that you provide directly to us, including:
- Device information (device ID, model, platform)
- Usage data (VPN connection logs, data usage statistics)
- Account information (balance, rewards, withdrawal requests)
- Location data (IP address, country, city)

2. HOW WE USE YOUR INFORMATION

We use the information we collect to:
- Provide and maintain the VPN service
- Process rewards and withdrawals
- Improve our services and user experience
- Communicate with you about your account
- Ensure security and prevent fraud

3. DATA STORAGE AND SECURITY

We use industry-standard security measures to protect your information. Your data is stored securely on Firebase servers with encryption in transit and at rest.

4. VPN CONNECTION LOGS

We maintain minimal connection logs necessary for:
- Service operation and troubleshooting
- Bandwidth management
- Security monitoring

We do not log:
- Websites you visit
- Content you access
- DNS queries
- Your browsing history

5. DATA RETENTION

We retain your data only as long as necessary to provide our services and comply with legal obligations. You can request deletion of your data at any time.

6. SHARING YOUR INFORMATION

We do not sell, trade, or rent your personal information to third parties. We may share information only:
- With your consent
- To comply with legal obligations
- To protect our rights and safety

7. YOUR RIGHTS

You have the right to:
- Access your personal data
- Request correction of inaccurate data
- Request deletion of your data
- Withdraw consent for data processing

8. COOKIES AND TRACKING

We use minimal tracking technologies necessary for app functionality. We do not use cookies for advertising purposes.

9. CHILDREN'S PRIVACY

Our service is not intended for children under 13. We do not knowingly collect information from children.

10. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. We will notify you of any changes by updating the "Last updated" date.

11. CONTACT US

If you have questions about this Privacy Policy, please contact us through the app's support features.

By using Suk Fhyoke VPN, you acknowledge that you have read and understood this Privacy Policy.""";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_sduiService.getText(_config['title'], 'Privacy Policy')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sduiService.getText(_config['title'], 'Privacy Policy'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: November 2025',
              style: TextStyle(color: subtitleColor),
            ),
            const SizedBox(height: 24),
            
            // Render content
            // For simple SDUI, we just display the full text or handle simple newlines
            Text(
              content,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: isDark ? Colors.grey.shade300 : Colors.black87,
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
