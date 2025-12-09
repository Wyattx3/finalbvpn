import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sdui_service.dart';
import '../utils/message_dialog.dart';
import '../user_manager.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final SduiService _sduiService = SduiService();
  final UserManager _userManager = UserManager();
  String selectedLanguage = 'English';
  
  // SDUI Data
  List<Map<String, dynamic>> languages = [];
  Map<String, dynamic> _config = {};
  bool _isLoading = true;

  // Default languages fallback
  static const List<Map<String, dynamic>> _defaultLanguages = [
    {'name': 'English', 'native': 'English'},
    {'name': 'Myanmar (Zawgyi)', 'native': 'မြန်မာ (ဇော်ဂျီ)'},
    {'name': 'Myanmar (Unicode)', 'native': 'မြန်မာ (ယူနီကုဒ်)'},
    {'name': 'Japanese', 'native': '日本語'},
    {'name': 'Chinese', 'native': '中文'},
    {'name': 'Thai', 'native': 'ไทย'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadServerConfig();
  }

  void _loadSettings() {
    selectedLanguage = _userManager.currentLanguage.value;
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('language');
      if (mounted) {
        if (response.containsKey('config') && response['config']['languages'] != null) {
          setState(() {
            _config = response['config'];
            languages = List<Map<String, dynamic>>.from(_config['languages'] ?? []);
            _isLoading = false;
          });
        } else {
          // Use defaults if no config
          setState(() {
            languages = List<Map<String, dynamic>>.from(_defaultLanguages);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("SDUI Error: $e");
      // Use defaults on error
      if (mounted) {
        setState(() {
          languages = List<Map<String, dynamic>>.from(_defaultLanguages);
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1625) : const Color(0xFFFAFAFC);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: backgroundColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
      appBar: AppBar(
          title: Text(_sduiService.getText(_config['title'], 'Language')),
          backgroundColor: backgroundColor,
          elevation: 0,
          centerTitle: true,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
          titleTextStyle: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
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
            final itemColor = isDark ? const Color(0xFF352F44) : Colors.white;

          return InkWell(
              onTap: () async {
                debugPrint('🌐 Language tapped: $name, current: $selectedLanguage');
                
                if (selectedLanguage == name) {
                  debugPrint('🌐 Already selected, skipping');
                  return;
                }
                
              setState(() {
                selectedLanguage = name;
              });
                
                debugPrint('🌐 Calling setLanguage($name)...');
                await _userManager.setLanguage(name);
                debugPrint('🌐 setLanguage completed. currentLanguage=${_userManager.currentLanguage.value}, currentLocale=${_userManager.currentLocale.value}');
                
                if (mounted) {
                  // Show dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Language Updated'),
                      content: Text('Language changed to $name.\nRestarting app...'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                  
                  // Wait for MaterialApp to rebuild
                  await Future.delayed(const Duration(milliseconds: 1500));
                  
                  if (mounted) {
                    debugPrint('🌐 Navigating back to home...');
                    // Close dialog first
                    Navigator.of(context).pop();
                    // Then pop to root
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                }
            },
              borderRadius: BorderRadius.circular(16),
            child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                      ? (isDark ? Colors.deepPurple.withOpacity(0.2) : Colors.deepPurple.withOpacity(0.05))
                      : itemColor,
                  borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(color: Colors.deepPurple, width: 1.5)
                    : null,
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Colors.deepPurple.withOpacity(0.1) 
                            : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.deepPurple : Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
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
                              fontSize: 13,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.deepPurple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                ],
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}
