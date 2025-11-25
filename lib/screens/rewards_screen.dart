import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../user_manager.dart';
import 'withdraw_success_screen.dart';
import 'withdraw_history_screen.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  bool isMMK = true;
  String? selectedPaymentMethod; // "Kpay", "Wave"
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController(text: '09');
  final UserManager _userManager = UserManager();

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // White icons for dark background
        statusBarBrightness: Brightness.dark, // iOS
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
        backgroundColor: Colors.transparent, // Transparent to show gradient
        resizeToAvoidBottomInset: true, // Handle keyboard overlay
        appBar: AppBar(
          title: const Text('My Rewards', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
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
        valueListenable: _userManager.balanceMMK,
        builder: (context, balance, child) {
          double usdValue = balance / 4500;
          final formattedBalance = _formatNumber(balance);

          return Column(
            children: [
              // Top Balance Section (Fixed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    const Text(
                      'Total Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isMMK ? '$formattedBalance MMK' : '\$${usdValue.toStringAsFixed(2)} USD',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Form Section (Expanded & Scrollable if needed)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: SingleChildScrollView(
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
                        const SizedBox(height: 30),

                        // Form Fields
                        if (isMMK) ...[
                          _buildLabel('Payment Method'),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: selectedPaymentMethod,
                            hint: const Text('Select Wallet'),
                            decoration: _inputDecoration(Icons.account_balance_wallet),
                            items: ['KBZ Pay', 'Wave Pay'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                selectedPaymentMethod = val;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                        ],

                        _buildLabel('Account Name'),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _accountNameController,
                          decoration: _inputDecoration(Icons.person),
                        ),
                        
                        const SizedBox(height: 20),

                        _buildLabel(isMMK ? 'Phone Number' : 'PayPal Email'),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _accountNumberController,
                          keyboardType: isMMK ? TextInputType.phone : TextInputType.emailAddress,
                          inputFormatters: isMMK ? [FilteringTextInputFormatter.digitsOnly] : [],
                          decoration: _inputDecoration(isMMK ? Icons.phone : Icons.email),
                        ),

                        const SizedBox(height: 30),

                        // Withdraw Button
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () => _handleWithdraw(balance, usdValue),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9575CD), // Soft purple
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Withdraw Now',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            isMMK 
                              ? 'Min: 20,000 MMK'
                              : 'Min: \$20.00 USD',
                            style: TextStyle(color: Colors.grey.shade500),
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
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
          border: isSelected ? Border.all(color: Colors.deepPurple) : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.deepPurple : Colors.grey,
              fontWeight: FontWeight.bold,
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
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.deepPurple),
      filled: true,
      fillColor: Colors.grey.shade500.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    );
  }

  void _handleWithdraw(int balance, double usdValue) {
    if (_accountNameController.text.isEmpty || _accountNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (isMMK && selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    // Simple Validation for MMK Phone (e.g., starts with 09)
    if (isMMK && !_accountNumberController.text.startsWith('09')) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number must start with 09')),
      );
      return;
    }

    if (isMMK) {
      if (balance >= 20000) {
        _showConfirmationDialog(() {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WithdrawSuccessScreen()),
        );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient balance. Min 20,000 MMK')),
        );
      }
    } else {
      if (usdValue >= 20.0) {
        _showConfirmationDialog(() {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WithdrawSuccessScreen()),
        );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient balance. Min \$20 USD')),
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
                        Navigator.pop(context); // Close dialog
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
