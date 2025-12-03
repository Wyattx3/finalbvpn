import 'package:flutter/material.dart';
import 'withdraw_history_details_screen.dart';
import '../services/mock_sdui_service.dart';

class WithdrawHistoryScreen extends StatefulWidget {
  const WithdrawHistoryScreen({super.key});

  @override
  State<WithdrawHistoryScreen> createState() => _WithdrawHistoryScreenState();
}

class _WithdrawHistoryScreenState extends State<WithdrawHistoryScreen> {
  final MockSduiService _sduiService = MockSduiService();
  Map<String, dynamic> _config = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('withdraw_history');
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
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5FA);
    final textColor = isDark ? Colors.white : Colors.black;
    final labels = _config['labels'] ?? {};

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_config['title'] ?? 'Withdraw History', style: TextStyle(color: textColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHistoryItem(
            context,
            amount: '25,000 MMK',
            date: 'Today, 2:30 PM',
            status: labels['pending'] ?? 'Pending',
            statusColor: Colors.orange,
            method: 'KBZ Pay',
            accountName: 'Mg Mg',
            accountNumber: '09123456789',
            transactionId: 'TXN7839201',
          ),
          _buildHistoryItem(
            context,
            amount: '\$20.00 USD',
            date: 'Nov 20, 2025',
            status: labels['completed'] ?? 'Completed',
            statusColor: Colors.green,
            method: 'PayPal',
            accountName: 'Kyaw Kyaw',
            accountNumber: 'kyaw@gmail.com',
            transactionId: 'TXN7839111',
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, {
    required String amount,
    required String date,
    required String status,
    required Color statusColor,
    required String method,
    required String accountName,
    required String accountNumber,
    required String transactionId,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WithdrawHistoryDetailsScreen(
              amount: amount,
              date: date,
              status: status,
              statusColor: statusColor,
              method: method,
              accountName: accountName,
              accountNumber: accountNumber,
              transactionId: transactionId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
