import 'package:flutter/material.dart';
import '../services/sdui_service.dart';
import '../utils/message_dialog.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final SduiService _sduiService = SduiService();
  String selectedLanguage = 'English';
  
  // SDUI Data
  List<Map<String, dynamic>> languages = [];
  Map<String, dynamic> _config = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('language');
      if (mounted) {
        if (response.containsKey('config')) {
          setState(() {
            _config = response['config'];
            languages = List<Map<String, dynamic>>.from(_config['languages'] ?? []);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_config['title'] ?? 'Language'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: languages.length,
        itemBuilder: (context, index) {
          final language = languages[index];
          final name = language['name'] ?? '';
          final native = language['native'] ?? '';
          final isSelected = selectedLanguage == name;

          return InkWell(
            onTap: () {
              setState(() {
                selectedLanguage = name;
              });
              showMessageDialog(
                context,
                message: 'Language changed to $name',
                type: MessageType.success,
                title: 'Language Updated',
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.deepPurple.withOpacity(0.1)
                    : (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: Colors.deepPurple, width: 1.5)
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.deepPurple : textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          native,
                          style: TextStyle(
                            fontSize: 14,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Colors.deepPurple),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
