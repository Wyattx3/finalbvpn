import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../user_manager.dart';
import '../services/sdui_service.dart';
import '../services/firebase_service.dart';
import '../utils/message_dialog.dart';
import '../utils/network_utils.dart';
import 'withdraw_success_screen.dart';
import 'withdraw_history_screen.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final SduiService _sduiService = SduiService();
  final UserManager _userManager = UserManager();
  final FirebaseService _firebaseService = FirebaseService();
  
  bool isMMK = true;
  String? selectedPaymentMethod; 
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController(text: '09');
  
  // SDUI Config
  Map<String, dynamic> _config = {};
  bool _isLoading = true;
  List<String> _paymentMethods = ['KBZ Pay', 'Wave Pay']; // Default fallback
  StreamSubscription? _sduiSubscription;

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
  }

  @override
  void dispose() {
    _sduiSubscription?.cancel();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  void _loadServerConfig() {
    debugPrint('🎁 Rewards: Starting real-time SDUI listener...');
    
    // Timeout fallback - if SDUI doesn't load in 3 seconds, show default UI
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        debugPrint('⚠️ Rewards: SDUI timeout - showing default UI');
        setState(() => _isLoading = false);
      }
    });
    
    _sduiSubscription?.cancel();
    _sduiSubscription = _sduiService.watchScreenConfig('rewards').listen(
      (response) {
        debugPrint('🎁 Rewards: Received SDUI update!');
        if (mounted) {
          if (response.containsKey('config')) {
            final config = response['config'];
            debugPrint('🎁 Rewards: Config received: ${config.keys}');
            debugPrint('🎁 Rewards: min_withdraw_mmk = ${config['min_withdraw_mmk']}');
            setState(() {
              _config = config;
              _paymentMethods = List<String>.from(config['payment_methods'] ?? ['KBZ Pay', 'Wave Pay']);
              _isLoading = false;
            });
            debugPrint('✅ Rewards: UI updated with real-time config');
          } else {
            setState(() => _isLoading = false);
          }
        }
      },
      onError: (e) {
        debugPrint("❌ Rewards SDUI Error: $e");
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  String _formatNumber(int number) {
    String numStr = number.toString();
    String result = '';
    int count = 0;
    for (int i = numStr.length - 1; i >= 0; i--) {
      count++;
      result = numStr[i] + result;
      if (count % 3 == 0 && i != 0) {
        result = ',$result';
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final labels = _config['labels'] ?? {};
    final minWithdrawMMK = (_config['min_withdraw_mmk'] as num?)?.toInt() ?? 20000;
    final minWithdrawUSD = (_config['min_withdraw_usd'] as num?)?.toDouble() ?? 20.0;

    // Screen Height calculation for responsive layout
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, 
        statusBarBrightness: Brightness.dark, 
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7E57C2), Color(0xFFB39DDB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false, // Fixed Position
          appBar: AppBar(
            title: Text(_config['title'] ?? 'My Rewards', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WithdrawHistoryScreen()),
                  );
                },
              ),
            ],
          ),
          body: ValueListenableBuilder<int>(
            valueListenable: _userManager.balancePoints,
            builder: (context, points, child) {
              final int balanceMMK = points;
              final double usdValue = points / 4500;
              final formattedPoints = _formatNumber(points);
              
              // Get keyboard height
              final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

              return Column(
                children: [
                  // Top Balance Section (Fixed but smaller)
                  SizedBox(
                    height: isSmallScreen ? 140 : 180, // Reduced height
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          labels['balance_label'] ?? 'Total Points',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        // Show Points Main
                        Text(
                          formattedPoints, 
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 36 : 42, // Smaller font
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Show Equivalent Value
                        Text(
                          '≈ ${_formatNumber(balanceMMK)} MMK / \$${usdValue.toStringAsFixed(2)} USD',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1 Point = 1 MMK | 4500 Points = 1 USD',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Form Section
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        child: Column(
                          children: [
                            // Scrollable Form Content
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Currency Toggle
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildTabButton('MMK', true),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildTabButton('USD', false),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Form Fields
                                    if (isMMK) ...[
                                      _buildLabel('Payment Method'),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: selectedPaymentMethod,
                                        hint: Text('Select Wallet', style: TextStyle(color: Colors.grey.shade500)),
                                        style: const TextStyle(color: Colors.black87, fontSize: 16),
                                        dropdownColor: Colors.white,
                                        decoration: _inputDecoration(Icons.account_balance_wallet),
                                        items: _paymentMethods.map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value, style: const TextStyle(color: Colors.black87)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            selectedPaymentMethod = val;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    _buildLabel('Account Name'),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _accountNameController,
                                      style: const TextStyle(color: Colors.black87),
                                      decoration: _inputDecoration(Icons.person),
                                    ),
                                    
                                    const SizedBox(height: 16),

                                    _buildLabel(isMMK ? 'Phone Number' : 'PayPal Email'),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _accountNumberController,
                                      style: const TextStyle(color: Colors.black87),
                                      keyboardType: isMMK ? TextInputType.phone : TextInputType.emailAddress,
                                      inputFormatters: isMMK ? [FilteringTextInputFormatter.digitsOnly] : [],
                                      decoration: _inputDecoration(isMMK ? Icons.phone : Icons.email),
                                    ),

                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Fixed Bottom Button (Inside White Card)
                            Container(
                              padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(top: BorderSide(color: Colors.grey.shade100)),
                              ),
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: () => _handleWithdraw(points, usdValue, minWithdrawMMK, minWithdrawUSD),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF9575CD),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        labels['withdraw_button'] ?? 'Withdraw Now',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isMMK 
                                      ? 'Min: ${_formatNumber(minWithdrawMMK)} Points'
                                      : 'Min: \$${minWithdrawUSD.toStringAsFixed(2)} USD',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, bool isForMMK) {
    final bool isSelected = isMMK == isForMMK;
    return GestureDetector(
      onTap: () {
        if (isMMK != isForMMK) {
          setState(() {
            isMMK = isForMMK;
            selectedPaymentMethod = null; // Reset selection
            if (isMMK) {
              _accountNumberController.text = '09';
            } else {
              _accountNumberController.clear();
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.deepPurple) : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.deepPurple : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.black87,
        fontSize: 13,
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.deepPurple, size: 20),
      filled: true,
      fillColor: Colors.grey.shade200,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _handleWithdraw(int points, double usdValue, int minMMK, double minUSD) {
    if (_accountNameController.text.isEmpty || _accountNumberController.text.isEmpty) {
      showMessageDialog(
        context,
        message: 'Please fill all fields',
        type: MessageType.error,
        title: 'Missing Information',
      );
      return;
    }

    if (isMMK && selectedPaymentMethod == null) {
      showMessageDialog(
        context,
        message: 'Please select a payment method',
        type: MessageType.error,
        title: 'Payment Method',
      );
      return;
    }

    if (isMMK && !_accountNumberController.text.startsWith('09')) {
      showMessageDialog(
        context,
        message: 'Phone number must start with 09',
        type: MessageType.error,
        title: 'Invalid Phone',
      );
      return;
    }

    if (isMMK) {
      if (points >= minMMK) {
        _showConfirmationDialog(() => _submitWithdrawal(points));
      } else {
        showMessageDialog(
          context,
          message: 'Insufficient points. Min ${_formatNumber(minMMK)} Points',
          type: MessageType.error,
          title: 'Insufficient Balance',
        );
      }
    } else {
      if (usdValue >= minUSD) {
        // Convert USD to points for submission (1 USD = 4500 MMK = 4500 points)
        final pointsToWithdraw = (usdValue * 4500).round();
        _showConfirmationDialog(() => _submitWithdrawal(pointsToWithdraw));
      } else {
        showMessageDialog(
          context,
          message: 'Insufficient balance. Min \$${minUSD.toStringAsFixed(2)} USD',
          type: MessageType.error,
          title: 'Insufficient Balance',
        );
      }
    }
  }

  Future<void> _submitWithdrawal(int amount) async {
    // Check network connection first
    final hasConnection = await NetworkUtils.hasInternetConnection();
    if (!hasConnection) {
      if (mounted) {
        NetworkUtils.showNetworkErrorDialog(context, onRetry: () => _submitWithdrawal(amount));
      }
      return;
    }
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _firebaseService.submitWithdrawal(
        amount: amount,
        method: isMMK ? selectedPaymentMethod! : 'PayPal',
        accountNumber: _accountNumberController.text,
        accountName: _accountNameController.text,
      );

      // Close loading
      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        debugPrint('✅ Withdrawal submitted: ${result['withdrawalId']}');
        // Refresh balance
        await _userManager.refreshBalance();
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WithdrawSuccessScreen()),
          );
        }
      } else {
        if (mounted) {
          showMessageDialog(
            context,
            message: result['error'] ?? 'Failed to submit withdrawal',
            type: MessageType.error,
            title: 'Error',
          );
        }
      }
    } catch (e) {
      // Close loading
      if (mounted) Navigator.pop(context);
      
      debugPrint('❌ Withdrawal error: $e');
      if (mounted) {
        showMessageDialog(
          context,
          message: 'Something went wrong. Please try again.',
          type: MessageType.error,
          title: 'Error',
        );
      }
    }
  }

  void _showConfirmationDialog(VoidCallback onConfirm) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Confirm Information',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Payment Method', isMMK ? selectedPaymentMethod! : 'PayPal'),
              _buildDetailRow('Account Name', _accountNameController.text),
              _buildDetailRow(isMMK ? 'Phone Number' : 'Email', _accountNumberController.text),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ],
      ),
    );
  }
}
