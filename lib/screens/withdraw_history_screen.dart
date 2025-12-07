import 'package:flutter/material.dart';
import 'dart:async';
import 'withdraw_history_details_screen.dart';
import '../services/firebase_service.dart';

class WithdrawHistoryScreen extends StatefulWidget {
  const WithdrawHistoryScreen({super.key});

  @override
  State<WithdrawHistoryScreen> createState() => _WithdrawHistoryScreenState();
}

class _WithdrawHistoryScreenState extends State<WithdrawHistoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription<List<Map<String, dynamic>>>? _withdrawalSubscription;
  List<Map<String, dynamic>> _withdrawals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _withdrawalSubscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    _withdrawalSubscription = _firebaseService.listenToWithdrawals().listen(
      (withdrawals) {
        if (mounted) {
          setState(() {
            _withdrawals = withdrawals;
            _isLoading = false;
          });
          debugPrint('📜 Withdrawal history updated: ${withdrawals.length} items');
        }
      },
      onError: (e) {
        debugPrint('❌ Withdrawal listener error: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Unknown';
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      final timeStr = '$hour:${date.minute.toString().padLeft(2, '0')} $amPm';
      
      if (diff.inDays == 0) {
        return 'Today, $timeStr';
      } else if (diff.inDays == 1) {
        return 'Yesterday, $timeStr';
      } else {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${months[date.month - 1]} ${date.day}, ${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatAmount(dynamic points) {
    final amount = (points ?? 0) as int;
    // Format with commas
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()} Points';
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Withdraw History', style: TextStyle(color: textColor)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: Colors.green, size: 14),
                  Text(
                    'Live',
                    style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _withdrawals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No withdrawal history',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    // Stream auto-updates, but user can pull to refresh
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _withdrawals.length,
                    itemBuilder: (context, index) {
                      final withdrawal = _withdrawals[index];
                      return _buildHistoryItem(
                        context,
                        withdrawal: withdrawal,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, {required Map<String, dynamic> withdrawal}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2640) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    
    final status = withdrawal['status'] as String?;
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final amount = _formatAmount(withdrawal['points']);
    final date = _formatDate(withdrawal['createdAt'] as String?);
    final method = withdrawal['method'] as String? ?? 'Unknown';
    final accountName = withdrawal['accountName'] as String? ?? 'Unknown';
    final accountNumber = withdrawal['accountNumber'] as String? ?? 'Unknown';
    final transactionId = withdrawal['id'] as String? ?? 'Unknown';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WithdrawHistoryDetailsScreen(
              amount: amount,
              date: date,
              status: statusText,
              statusColor: statusColor,
              method: method,
              accountName: accountName,
              accountNumber: accountNumber,
              transactionId: withdrawal['transactionId'] as String? ?? transactionId,
              receiptUrl: withdrawal['receiptUrl'] as String?,
              rejectionReason: withdrawal['rejectionReason'] as String?,
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
          children: [
            // Icon based on status
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                status == 'approved' ? Icons.check_circle :
                status == 'rejected' ? Icons.cancel :
                Icons.hourglass_empty,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Amount and date
            Expanded(
              child: Column(
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
                    '$method • $date',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText,
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
