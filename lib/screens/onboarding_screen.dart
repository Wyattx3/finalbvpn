import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mock_sdui_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final MockSduiService _sduiService = MockSduiService();
  
  int _currentPage = 0;
  bool _isLoading = true;
  
  // Data fetched from Server (SDUI)
  List<Map<String, dynamic>> _pages = [];
  Map<String, String> _assets = {};

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
  }

  Future<void> _loadServerConfig() async {
    try {
      final response = await _sduiService.getScreenConfig('onboarding');
      
      if (response.containsKey('config')) {
        final config = response['config'];
        
        if (mounted) {
          setState(() {
            _pages = List<Map<String, dynamic>>.from(config['pages']);
            _assets = Map<String, String>.from(config['assets']);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading SDUI config: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_pages.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text("Failed to load configuration"),
        ),
      );
    }

    // Apply System UI Overlay Style for Transparent Status Bar with White Icons
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Allow image to show through
        statusBarIconBrightness: Brightness.light, // White icons for Android
        statusBarBrightness: Brightness.dark, // White icons for iOS (Dark content means light text)
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true, // Crucial for image to go behind status bar
        body: Stack(
          children: [
            // Page Content (Full Screen Images)
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return _buildPage(_pages[index]);
              },
            ),

            // Pagination Dots (Left Bottom)
            Positioned(
              left: 24,
              bottom: 73,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_pages.length, (index) {
                  bool isActive = _currentPage == index;
                  final dotPrefix = _assets['dot_prefix'] ?? 'assets/images/onboarding/dot';
                  final imagePath = '$dotPrefix ${index + 1}.png';

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(right: 6),
                    height: isActive ? 30 : 18,
                    width: isActive ? 30 : 18,
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => Container(color: Colors.grey),
                    ),
                  );
                }),
              ),
            ),

            // Next/Get Started Button (Right Bottom Corner)
            Positioned(
              right: -30,
              bottom: -50,
              child: GestureDetector(
                onTap: _onNext,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: 400,
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  child: Image.asset(
                    _currentPage == _pages.length - 1
                        ? (_assets['start_button'] ?? 'assets/images/onboarding/get start.png')
                        : (_assets['next_button'] ?? 'assets/images/onboarding/next.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(Map<String, dynamic> page) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full Screen Background Image
        Image.asset(
          page['image'],
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(color: Colors.grey[300]);
          },
        ),
        
        // Text Overlay - Absolute Center
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  page['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Serif',
                    color: Colors.black,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  page['description'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
