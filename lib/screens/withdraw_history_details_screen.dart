import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/sdui_service.dart';

class WithdrawHistoryDetailsScreen extends StatefulWidget {
  final String amount;
  final String date;
  final String status;
  final Color statusColor;
  final String method;
  final String accountName;
  final String accountNumber;
  final String transactionId;
  final String? receiptUrl;
  final String? rejectionReason;

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
    this.receiptUrl,
    this.rejectionReason,
  });

  @override
  State<WithdrawHistoryDetailsScreen> createState() => _WithdrawHistoryDetailsScreenState();
}

class _WithdrawHistoryDetailsScreenState extends State<WithdrawHistoryDetailsScreen> {
  final SduiService _sduiService = SduiService();
  Map<String, dynamic> _config = {};
  Map<String, dynamic> _labels = {};
  bool _isLoading = true;
  bool _showFullReceipt = false;

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
    final bgColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF2D2640) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_sduiService.getText(_config['title'], 'Transaction Details')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Status Icon & Amount Section (Top)
              Expanded(
                flex: 2,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: widget.statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.status == 'Completed' 
                              ? Icons.check_circle 
                              : widget.status == 'Rejected'
                                  ? Icons.cancel
                                  : Icons.access_time_filled,
                          size: 50,
                          color: widget.statusColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.amount,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: widget.statusColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sduiService.getText(_labels['transaction_info'], 'Transaction Information'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        _buildDetailRow(_sduiService.getText(_labels['date'], 'Date'), widget.date, textColor),
                        _buildDivider(isDark),
                        _buildDetailRow(_sduiService.getText(_labels['payment_method'], 'Payment Method'), widget.method, textColor),
                        _buildDivider(isDark),
                        _buildDetailRow(_sduiService.getText(_labels['account_name'], 'Account Name'), widget.accountName, textColor),
                        _buildDivider(isDark),
                        _buildDetailRow(_sduiService.getText(_labels['account_number'], 'Account Number'), widget.accountNumber, textColor),
                        
                        // Transaction ID - only show if completed
                        if (widget.status == 'Completed' && widget.transactionId.isNotEmpty && widget.transactionId != 'Unknown') ...[
                          _buildDivider(isDark),
                          _buildDetailRow(
                            _sduiService.getText(_labels['transaction_id'], 'Transaction ID'), 
                            widget.transactionId, 
                            textColor,
                            valueColor: Colors.green,
                          ),
                        ],
                        
                        // Rejection Reason - only show if rejected
                        if (widget.status == 'Rejected' && widget.rejectionReason != null) ...[
                          _buildDivider(isDark),
                          _buildDetailRow(
                            'Rejection Reason', 
                            widget.rejectionReason!, 
                            textColor,
                            valueColor: Colors.red,
                          ),
                        ],
                        
                        // Receipt Image - only show if available
                        if (widget.receiptUrl != null && widget.receiptUrl!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Payment Receipt',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => setState(() => _showFullReceipt = true),
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _buildReceiptImage(widget.receiptUrl!, isDark),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Tap to view full image',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Full Screen Receipt Viewer
          if (_showFullReceipt && widget.receiptUrl != null)
            GestureDetector(
              onTap: () => setState(() => _showFullReceipt = false),
              child: Container(
                color: Colors.black.withOpacity(0.9),
                child: Stack(
                  children: [
                    Center(
                      child: InteractiveViewer(
                        child: _buildReceiptImage(widget.receiptUrl!, isDark, fit: BoxFit.contain),
                      ),
                    ),
                    Positioned(
                      top: 50,
                      right: 20,
                      child: IconButton(
                        onPressed: () => setState(() => _showFullReceipt = false),
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
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

  Widget _buildReceiptImage(String receiptUrl, bool isDark, {BoxFit fit = BoxFit.cover}) {
    // Check if it's a base64 data URI
    if (receiptUrl.startsWith('data:image')) {
      try {
        // Extract base64 data from data URI
        final base64Data = receiptUrl.split(',').last;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget(isDark);
          },
        );
      } catch (e) {
        return _buildErrorWidget(isDark);
      }
    }
    
    // Otherwise treat as URL
    return Image.network(
      receiptUrl,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: 150,
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildErrorWidget(isDark);
      },
    );
  }

  Widget _buildErrorWidget(bool isDark) {
    return Container(
      height: 150,
      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.grey, size: 40),
            const SizedBox(height: 8),
            Text('Failed to load receipt', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color textColor, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
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
                color: valueColor ?? textColor,
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
