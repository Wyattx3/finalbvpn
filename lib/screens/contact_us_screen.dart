import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sdui_service.dart';
import '../services/firebase_service.dart';
import '../utils/message_dialog.dart';
import 'live_chat_screen.dart';
import 'faq_screen.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final SduiService _sduiService = SduiService();
  final FirebaseService _firebaseService = FirebaseService();
  
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String selectedCategory = 'General Inquiry';
  bool _isSubmitting = false;

  // SDUI Config
  Map<String, dynamic> _config = {};
  bool _isLoading = true;

  final List<String> categories = [
    'General Inquiry',
    'Technical Support',
    'Billing Issue',
    'Feature Request',
    'Bug Report',
    'Account Problem',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('contact_us');
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
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
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
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50;
    
    final contactEmail = _config['email'] ?? 'support@sukfhyoke.com';
    final telegramHandle = _config['telegram'] ?? '@sukfhyoke_support';

    return Scaffold(
      appBar: AppBar(
        title: Text(_sduiService.getText(_config['title'], 'Contact Us')),
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
            // Contact Options
            Text(
              'Get in Touch',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'re here to help! Choose your preferred contact method.',
              style: TextStyle(color: subtitleColor),
            ),
            const SizedBox(height: 24),

            // Quick Contact Cards
            Row(
              children: [
                Expanded(
                  child: _buildContactCard(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: contactEmail,
                    onTap: () async {
                      try {
                        final Uri emailUri = Uri(
                          scheme: 'mailto',
                          path: contactEmail,
                        );
                        if (await canLaunchUrl(emailUri)) {
                          await launchUrl(emailUri);
                        } else {
                          // Fallback to copy if email app not available
                          Clipboard.setData(ClipboardData(text: contactEmail));
                          if (mounted) {
                            showMessageDialog(
                              context,
                              message: 'Email copied to clipboard',
                              type: MessageType.success,
                              title: 'Copied',
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint('Error opening email: $e');
                        Clipboard.setData(ClipboardData(text: contactEmail));
                        if (mounted) {
                          showMessageDialog(
                            context,
                            message: 'Email copied to clipboard',
                            type: MessageType.success,
                            title: 'Copied',
                          );
                        }
                      }
                    },
                    cardColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildContactCard(
                    icon: Icons.telegram,
                    title: 'Telegram',
                    subtitle: telegramHandle,
                    onTap: () async {
                      try {
                        // Remove @ if present and create telegram URL
                        final telegramUsername = telegramHandle.replaceFirst('@', '');
                        final Uri telegramUri = Uri.parse('https://t.me/$telegramUsername');
                        
                        // Try to open Telegram app first
                        final Uri telegramAppUri = Uri.parse('tg://resolve?domain=$telegramUsername');
                        
                        if (await canLaunchUrl(telegramAppUri)) {
                          await launchUrl(telegramAppUri);
                        } else if (await canLaunchUrl(telegramUri)) {
                          await launchUrl(telegramUri, mode: LaunchMode.externalApplication);
                        } else {
                          if (mounted) {
                            showMessageDialog(
                              context,
                              message: 'Could not open Telegram. Please install Telegram app.',
                              type: MessageType.error,
                              title: 'Error',
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint('Error opening Telegram: $e');
                        if (mounted) {
                          showMessageDialog(
                            context,
                            message: 'Error opening Telegram: $e',
                            type: MessageType.error,
                            title: 'Error',
                          );
                        }
                      }
                    },
                    cardColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildContactCard(
                    icon: Icons.chat_bubble_outline,
                    title: 'Live Chat',
                    subtitle: '24/7 Support',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LiveChatScreen()),
                      );
                    },
                    cardColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildContactCard(
                    icon: Icons.help_outline,
                    title: 'FAQ',
                    subtitle: 'Common Questions',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FAQScreen()),
                      );
                    },
                    cardColor: cardColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            const SizedBox(height: 24),

            // Contact Form
            Text(
              'Send us a Message',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            Text(
              'Category',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                  items: categories.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: TextStyle(color: textColor)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedCategory = val!;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Email Field
            Text(
              'Your Email',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Enter your email address',
                hintStyle: TextStyle(color: subtitleColor),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Subject Field
            Text(
              'Subject',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Enter subject',
                hintStyle: TextStyle(color: subtitleColor),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Message Field
            Text(
              'Message',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 5,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Describe your issue or question...',
                hintStyle: TextStyle(color: subtitleColor),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Response Time Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.deepPurple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'We typically respond within 24 hours. For urgent issues, please use Live Chat.',
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.deepPurple, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: subtitleColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_subjectController.text.isEmpty || _messageController.text.isEmpty || _emailController.text.isEmpty) {
      showMessageDialog(
        context,
        message: 'Please fill in all fields',
        type: MessageType.error,
        title: 'Missing Information',
      );
      return;
    }

    // Basic email validation
    if (!_emailController.text.contains('@') || !_emailController.text.contains('.')) {
      showMessageDialog(
        context,
        message: 'Please enter a valid email address',
        type: MessageType.error,
        title: 'Invalid Email',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final deviceId = await _firebaseService.getDeviceId();
      
      // Send message via API
      final response = await _firebaseService.sendContactMessage(
        category: selectedCategory,
        subject: _subjectController.text,
        message: _messageController.text,
        email: _emailController.text.trim(),
        deviceId: deviceId,
      );

      if (mounted) {
        if (response['success'] == true) {
          showMessageDialog(
            context,
            message: 'Thank you for contacting us. We will get back to you via email within 24 hours.',
            type: MessageType.success,
            title: 'Message Sent!',
          );
          
          // Clear form after successful submission
          _subjectController.clear();
          _messageController.clear();
          _emailController.clear();
          setState(() {
            selectedCategory = 'General Inquiry';
          });
        } else {
          showMessageDialog(
            context,
            message: response['error'] ?? 'Failed to send message. Please try again.',
            type: MessageType.error,
            title: 'Error',
          );
        }
      }
    } catch (e) {
      debugPrint('Error submitting form: $e');
      if (mounted) {
        showMessageDialog(
          context,
          message: 'Failed to send message. Please check your internet connection and try again.',
          type: MessageType.error,
          title: 'Error',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
