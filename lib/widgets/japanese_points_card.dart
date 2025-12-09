import 'dart:math' as math;
import 'package:flutter/material.dart';

class JapanesePointsCard extends StatefulWidget {
  final int balance;
  final String currency;
  final int todayEarned;
  final bool isDark;

  const JapanesePointsCard({
    Key? key,
    required this.balance,
    required this.currency,
    required this.todayEarned,
    required this.isDark,
  }) : super(key: key);

  @override
  State<JapanesePointsCard> createState() => _JapanesePointsCardState();
}

class _JapanesePointsCardState extends State<JapanesePointsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Loop the animation continuously
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    final usdValue = widget.balance / 4500;
    
    // Choose gradient based on theme
    final List<Color> bgColors = widget.isDark 
        ? [const Color(0xFF6D28D9), const Color(0xFF8B5CF6)] // Dark violet
        : [const Color(0xFF00B4D8), const Color(0xFF48CAE4)]; // Cyan/Blue
        
    final Color shadowColor = widget.isDark 
        ? const Color(0xFF6C5CE7).withOpacity(0.3)
        : const Color(0xFF00B4D8).withOpacity(0.3);

    return Container(
      width: double.infinity,
      height: 220, // Fixed height for proper Stack layout
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      // ClipRRect creates the rounded corners for the canvas and content
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Animation Layer
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: WavePainter(
                    animationValue: _controller.value,
                    colors: bgColors,
                    isDark: widget.isDark,
                  ),
                );
              },
            ),

            // 2. Content Layer
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      "Total Points",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    
                    // Points Value
                    Text(
                      _formatNumber(widget.balance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Conversion Rate
                    Text(
                      "≈ ${_formatNumber(widget.balance)} MMK / \$${usdValue.toStringAsFixed(2)} USD",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    
                    // Point Definition
                    Text(
                      "1 Point = 1 MMK",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // Glass Badge (Today: +30 Points)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "Today: +${_formatNumber(widget.todayEarned)} ${widget.currency}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- The Custom Painter ---

class WavePainter extends CustomPainter {
  final double animationValue;
  final List<Color> colors;
  final bool isDark;

  WavePainter({
    required this.animationValue, 
    required this.colors,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Static Gradient Background
    final Rect rect = Offset.zero & size;
    final Paint gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect);

    canvas.drawRect(rect, gradientPaint);

    // 2. Draw Waves
    // We use animationValue (0.0 to 1.0) multiplied by 2*pi for seamless loops
    final double time = animationValue * 2 * math.pi;

    // Define wave colors based on theme
    final Color backWaveColor = isDark 
        ? const Color(0xFF6432C8).withOpacity(0.4) 
        : const Color(0xFF0077B6).withOpacity(0.4);
        
    final Color midWaveColor = isDark 
        ? const Color(0xFF8250FA).withOpacity(0.5) 
        : const Color(0xFF0096C7).withOpacity(0.5);
        
    final Color frontWaveColor = isDark 
        ? const Color(0xFFA29BFE).withOpacity(0.6) 
        : const Color(0xFF90E0EF).withOpacity(0.6);

    // Layer 1 (Back) - Darker
    _drawJapaneseWave(
      canvas: canvas,
      size: size,
      baseY: size.height * 0.45,
      amplitude: 15,
      frequency: 0.015,
      phase: time,
      color: backWaveColor,
    );

    // Layer 2 (Middle) - Medium
    _drawJapaneseWave(
      canvas: canvas,
      size: size,
      baseY: size.height * 0.6,
      amplitude: 20,
      frequency: 0.02,
      phase: time * 2.0 + 2, // Different speed and offset
      color: midWaveColor,
      strokeColor: Colors.white.withOpacity(0.1),
    );

    // Layer 3 (Front) - Lightest
    _drawJapaneseWave(
      canvas: canvas,
      size: size,
      baseY: size.height * 0.75,
      amplitude: 12,
      frequency: 0.03,
      phase: time * 3.0 + 1,
      color: frontWaveColor,
      strokeColor: Colors.white.withOpacity(0.3),
    );
  }

  void _drawJapaneseWave({
    required Canvas canvas,
    required Size size,
    required double baseY,
    required double amplitude,
    required double frequency,
    required double phase,
    required Color color,
    Color? strokeColor,
  }) {
    final Path path = Path();
    final Path strokePath = Path(); // For the "foam" line on top

    path.moveTo(0, size.height); // Start bottom left
    path.lineTo(0, baseY);

    strokePath.moveTo(0, baseY);

    for (double x = 0; x <= size.width; x++) {
      // Complex Sine Formula for "Pointy" Seigaiha Style
      // y = base + sin(A) * amp + sin(B) * (amp * 0.4)
      double y = baseY +
          math.sin(x * frequency + phase) * amplitude +
          math.sin(x * frequency * 2.5 + phase * 1.5) * (amplitude * 0.4);

      path.lineTo(x, y);
      if (strokeColor != null) {
        strokePath.lineTo(x, y);
      }
    }

    path.lineTo(size.width, size.height); // Bottom right
    path.close();

    // Fill
    final Paint fillPaint = Paint()..color = color;
    canvas.drawPath(path, fillPaint);

    // Stroke (Foam)
    if (strokeColor != null) {
      final Paint strokePaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(strokePath, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return true; // Repaint every frame
  }
}
