import 'dart:math' as math;
import 'package:flutter/material.dart';

class JapaneseWaveBackground extends StatefulWidget {
  const JapaneseWaveBackground({Key? key}) : super(key: key);

  @override
  State<JapaneseWaveBackground> createState() => _JapaneseWaveBackgroundState();
}

class _JapaneseWaveBackgroundState extends State<JapaneseWaveBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Continuous animation loop
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // Speed of the wave cycle
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent, // Background managed by parent or stacked behind
      width: double.infinity,
      height: double.infinity,
      child: CustomPaint(
        painter: WavePainter(animation: _controller),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final Animation<double> animation;

  WavePainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // We draw 3 layers to create depth (Parallax effect)

    // Layer 1: Furthest back (Lightest, Slowest)
    _drawSmoothWave(
      canvas,
      size,
      baseY: size.height * 0.65, // Position
      freq: 0.003,               // How wide the waves are
      amp: 40,                   // Wave height
      speedMult: 1.0,            // Animation speed
      color: const Color.fromRGBO(173, 216, 230, 0.2), // LightBlue
      phaseOffset: 0,
    );

    // Layer 2: Middle (Medium opacity)
    _drawSmoothWave(
      canvas,
      size,
      baseY: size.height * 0.75,
      freq: 0.005,
      amp: 35,
      speedMult: 1.5,
      color: const Color.fromRGBO(135, 206, 235, 0.2), // SkyBlue
      phaseOffset: 2,
    );

    // Layer 3: Closest (Darker, slightly faster)
    _drawSmoothWave(
      canvas,
      size,
      baseY: size.height * 0.85,
      freq: 0.004,
      amp: 30,
      speedMult: 1.2,
      color: const Color.fromRGBO(135, 206, 250, 0.25), // LightSkyBlue
      phaseOffset: 4,
    );
  }

  void _drawSmoothWave(
    Canvas canvas,
    Size size, {
    required double baseY,
    required double freq,
    required double amp,
    required double speedMult,
    required Color color,
    required double phaseOffset,
  }) {
    final paint = Paint()..color = color;
    final path = Path();

    // Start drawing from bottom-left
    path.moveTo(0, size.height);
    path.lineTo(0, baseY);

    // Calculate current time shift based on animation controller
    // 2 * pi ensures a seamless loop
    final shift = (animation.value * 2 * math.pi * speedMult) + phaseOffset;

    // Draw the sine wave pixel by pixel across the width
    for (double x = 0; x <= size.width; x++) {
      // Sine wave formula: y = Base + sin(x * frequency + time) * amplitude
      final y = baseY + math.sin(x * freq + shift) * amp;
      path.lineTo(x, y);
    }

    // Close the shape at bottom-right
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return true; // Always repaint as animation updates
  }
}

