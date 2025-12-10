import 'package:flutter/material.dart';
import '../services/sdui_service.dart';

class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({super.key});

  @override
  State<TermsOfServiceScreen> createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
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
      final response = await _sduiService.getScreenConfig('terms_of_service');
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
      content = """1. ACCEPTANCE OF TERMS

By accessing and using Suk Fhyoke VPN, you accept and agree to be bound by the terms and provision of this agreement.

2. USE OF SERVICE

You agree to use the VPN service only for lawful purposes and in accordance with these Terms of Service. You are responsible for all activities that occur under your account.

3. PROHIBITED ACTIVITIES

You may not use the service to:
- Engage in any illegal activities
- Transmit malicious software or viruses
- Violate any applicable laws or regulations
- Infringe upon intellectual property rights

4. ACCOUNT SECURITY

You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.

5. SERVICE AVAILABILITY

We strive to provide reliable service but do not guarantee uninterrupted or error-free service. We reserve the right to modify or discontinue the service at any time.

6. LIMITATION OF LIABILITY

Suk Fhyoke VPN shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the service.

7. TERMINATION

We reserve the right to terminate or suspend your account and access to the service at our sole discretion, without prior notice, for conduct that we believe violates these Terms of Service.

8. CHANGES TO TERMS

We reserve the right to modify these terms at any time. Your continued use of the service after any changes constitutes acceptance of the new terms.

9. CONTACT INFORMATION

If you have any questions about these Terms of Service, please contact us through the app's support features.

Effective Date: November 2025""";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_sduiService.getText(_config['title'], 'Terms of Service')),
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
              _sduiService.getText(_config['title'], 'Terms of Service'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Effective Date: November 2025',
              style: TextStyle(color: subtitleColor),
            ),
            const SizedBox(height: 24),
            
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
