import 'package:flutter/material.dart';
import '../services/sdui_service.dart';
import '../user_manager.dart';

class VpnProtocolScreen extends StatefulWidget {
  const VpnProtocolScreen({super.key});

  @override
  State<VpnProtocolScreen> createState() => _VpnProtocolScreenState();
}

class _VpnProtocolScreenState extends State<VpnProtocolScreen> {
  final SduiService _sduiService = SduiService();
  final UserManager _userManager = UserManager();
  
  // 0: Auto, 1: TCP, 2: UDP
  int _selectedOption = 0;

  // SDUI Config
  Map<String, dynamic> _config = {};
  List<Map<String, dynamic>> _protocols = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Load current selection from UserManager
    _selectedOption = _userManager.vpnProtocol.value;
    _loadServerConfig();
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('vpn_protocol');
      if (mounted) {
        if (response.containsKey('config')) {
          setState(() {
            _config = response['config'];
            _protocols = List<Map<String, dynamic>>.from(_config['protocols'] ?? []);
            _isLoading = false;
          });
        } else {
          // Use default protocols if SDUI not configured
          setState(() {
            _protocols = [
              {'index': 0, 'title': 'Auto (WebSocket)', 'description': 'Recommended - Best compatibility, uses port 443'},
              {'index': 1, 'title': 'TCP', 'description': 'Direct TCP connection on port 8443'},
              {'index': 2, 'title': 'UDP (QUIC)', 'description': 'Fast UDP connection on port 4434, better for streaming'},
            ];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("SDUI Error: $e");
      if (mounted) {
        setState(() {
          // Use default protocols on error
          _protocols = [
            {'index': 0, 'title': 'Auto (WebSocket)', 'description': 'Recommended - Best compatibility, uses port 443'},
            {'index': 1, 'title': 'TCP', 'description': 'Direct TCP connection on port 8443'},
            {'index': 2, 'title': 'UDP (QUIC)', 'description': 'Fast UDP connection on port 4434, better for streaming'},
          ];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_config['title'] ?? 'VPN Protocol'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: _protocols.map((protocol) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildOption(
                index: protocol['index'] ?? 0,
                title: protocol['title'] ?? '',
                description: protocol['description'],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOption({
    required int index,
    required String title,
    String? description,
  }) {
    final isSelected = _selectedOption == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOption = index;
          // Save to UserManager
          _userManager.vpnProtocol.value = index;
        });
        
        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Protocol changed to ${_userManager.getProtocolName()}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.deepPurple,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: Colors.deepPurple.withOpacity(0.5), width: 1) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.deepPurple : Colors.transparent,
                border: Border.all(
                  color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
