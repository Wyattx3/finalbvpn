import 'package:flutter/material.dart';
import '../services/mock_sdui_service.dart';

class WithdrawHistoryDetailsScreen extends StatefulWidget {
  final String amount;
  final String date;
  final String status;
  final Color statusColor;
  final String method;
  final String accountName;
  final String accountNumber;
  final String transactionId;

  const WithdrawHistoryDetailsScreen({
    super.key,
    required this.amount,
    required this.date,
    required this.status,
    required this.statusColor,
    required this.method,
    required this.accountName,
    required this.accountNumber,
    required this.transactionId,
  });

  @override
  State<WithdrawHistoryDetailsScreen> createState() => _WithdrawHistoryDetailsScreenState();
}

class _WithdrawHistoryDetailsScreenState extends State<WithdrawHistoryDetailsScreen> {
  final MockSduiService _sduiService = MockSduiService();
  Map<String, dynamic> _config = {};
  Map<String, dynamic> _labels = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('withdraw_details');
      if (mounted) {
        if (response.containsKey('config')) {
          setState(() {
            _config = response['config'];
            _labels = Map<String, dynamic>.from(_config['labels'] ?? {});
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
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_config['title'] ?? 'Transaction Details'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: Column(
        children: [
          // Status Icon & Amount Section (Top)
          Expanded(
            flex: 3,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: widget.statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.status == 'Completed' ? Icons.check_circle : Icons.access_time_filled,
                      size: 60,
                      color: widget.statusColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.amount,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: widget.statusColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.status,
                      style: TextStyle(
                        color: widget.statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Details Section (Bottom)
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _labels['transaction_info'] ?? 'Transaction Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildDetailRow(_labels['date'] ?? 'Date', widget.date, textColor),
                        _buildDivider(isDark),
                        _buildDetailRow(_labels['payment_method'] ?? 'Payment Method', widget.method, textColor),
                        _buildDivider(isDark),
                        _buildDetailRow(_labels['account_name'] ?? 'Account Name', widget.accountName, textColor),
                        _buildDivider(isDark),
                        _buildDetailRow(_labels['account_number'] ?? 'Account Number', widget.accountNumber, textColor),
                        _buildDivider(isDark),
                        _buildDetailRow(_labels['transaction_id'] ?? 'Transaction ID', widget.transactionId, textColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      height: 1,
      thickness: 1,
    );
  }
}
