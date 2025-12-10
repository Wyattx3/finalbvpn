import 'package:flutter/material.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final List<FAQItem> _faqs = [
    FAQItem(
      question: 'How do I connect to VPN?',
      answer:
          'Simply tap the connect button on the home screen. Make sure you have VPN time remaining. You can earn VPN time by watching ads.',
    ),
    FAQItem(
      question: 'How do I earn VPN time?',
      answer:
          'You can earn VPN time by watching short ads. Each ad gives you 2 hours of VPN time. You can also earn points that can be converted to VPN time.',
    ),
    FAQItem(
      question: 'How do I withdraw my earnings?',
      answer:
          'Go to the Rewards section, tap on "Withdraw", enter your payment details, and submit your withdrawal request. Minimum withdrawal is 20,000 MMK.',
    ),
    FAQItem(
      question: 'Why is my VPN connection slow?',
      answer:
          'VPN speed depends on your internet connection, server location, and server load. Try connecting to a different server or check your internet connection.',
    ),
    FAQItem(
      question: 'Can I use VPN on multiple devices?',
      answer:
          'Your account is tied to your device ID. Each device has its own account and VPN time. You cannot share VPN time between devices.',
    ),
    FAQItem(
      question: 'How do I change my server location?',
      answer:
          'Disconnect from VPN first, then tap on the location selector to choose a different server location.',
    ),
    FAQItem(
      question: 'What payment methods are supported?',
      answer:
          'We support KBZ Pay and Wave Pay for withdrawals. More payment methods may be added in the future.',
    ),
    FAQItem(
      question: 'How long does withdrawal take?',
      answer:
          'Withdrawal requests are typically processed within 24-48 hours. You will be notified once your withdrawal is approved.',
    ),
    FAQItem(
      question: 'Why was my account banned?',
      answer:
          'Accounts may be banned for violating terms of service, suspicious activity, or abuse. Contact support if you believe your account was banned by mistake.',
    ),
    FAQItem(
      question: 'How do I update the app?',
      answer:
          'You can update the app from Google Play Store. If a force update is required, you will see a popup when opening the app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Frequently Asked Questions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        itemBuilder: (context, index) {
          return _buildFAQItem(_faqs[index], isDark, textColor, subtitleColor, cardColor);
        },
      ),
    );
  }

  Widget _buildFAQItem(
    FAQItem faq,
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color cardColor,
  ) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      backgroundColor: cardColor,
      collapsedBackgroundColor: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(
        faq.question,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
          fontSize: 15,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            faq.answer,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}

