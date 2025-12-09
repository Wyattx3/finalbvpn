import 'dart:math' as math;
import 'package:flutter/material.dart';

class ZenCoinIcon extends StatefulWidget {
  final double size;
  const ZenCoinIcon({super.key, required this.size});

  @override
  State<ZenCoinIcon> createState() => _ZenCoinIconState();
}

class _ZenCoinIconState extends State<ZenCoinIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _ZenCoinPainter(_controller.value),
        );
      },
    );
  }
}

class _ZenCoinPainter extends CustomPainter {
  final double animationValue;
  _ZenCoinPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double time = animationValue * 2 * math.pi;
    
    // Bobbing Animation (Up and Down)
    final double bobY = math.sin(time) * 2.0; // Reduced amplitude for smaller icons
    final Offset coinCenter = Offset(center.dx, center.dy + bobY);
    final double radius = size.width * 0.4;

    final Paint goldPaint = Paint()..color = const Color(0xFFF59E0B);
    final Paint darkGoldStroke = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03; // Scale stroke width

    // 1. Draw Coin Body (With Square Hole using Path Operation)
    Path coinPath = Path()
      ..addOval(Rect.fromCircle(center: coinCenter, radius: radius));

    // Create Square Hole Path
    double holeSize = radius * 0.35;
    Path holePath = Path()
      ..addRect(Rect.fromCenter(
          center: coinCenter, width: holeSize, height: holeSize));

    // Combine: Outer Circle minus Inner Square
    Path finalShape = Path.combine(PathOperation.difference, coinPath, holePath);
    
    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + radius + (size.width * 0.1)), width: radius * 1.5, height: radius * 0.3), 
      Paint()..color = Colors.black.withOpacity(0.1 - (bobY/20).clamp(-0.1, 0.1)) // Shadow fades when coin goes up
    );

    canvas.drawPath(finalShape, goldPaint);
    canvas.drawPath(finalShape, darkGoldStroke);

    // Inner Ring Decoration
    canvas.drawCircle(
      coinCenter,
      radius * 0.75,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.015,
    );

    // 2. Shine Effect (Masking)
    canvas.save();
    canvas.clipPath(finalShape); // Clip to coin shape

    final double shinePos = (animationValue * size.width * 2) - size.width;
    
    final Path shinePath = Path()
      ..moveTo(shinePos, coinCenter.dy - radius)
      ..lineTo(shinePos + (size.width * 0.4), coinCenter.dy - radius)
      ..lineTo(shinePos - (size.width * 0.2), coinCenter.dy + radius)
      ..lineTo(shinePos - (size.width * 0.6), coinCenter.dy + radius)
      ..close();

    canvas.drawPath(shinePath, Paint()..color = Colors.white.withOpacity(0.3));
    canvas.restore();

    // 3. Sparkles
    _drawSparkle(canvas, center, -size.width * 0.4, -size.width * 0.4, time, 0, size.width);
    _drawSparkle(canvas, center, size.width * 0.4, size.width * 0.4, time, 2, size.width);
    _drawSparkle(canvas, center, -size.width * 0.5, size.width * 0.3, time, 4, size.width);
  }

  void _drawSparkle(Canvas canvas, Offset center, double dx, double dy, double time, double offset, double baseSize) {
    // Pulse size
    double size = (math.sin(time + offset).abs()) * (baseSize * 0.06);
    if (size < 0) size = 0;
    
    final Paint sparklePaint = Paint()..color = const Color(0xFFFBBF24);
    final double cx = center.dx + dx;
    final double cy = center.dy + dy;

    Path starPath = Path();
    starPath.moveTo(cx, cy - size * 2); // Top
    starPath.quadraticBezierTo(cx, cy, cx + size * 2, cy); // Right
    starPath.quadraticBezierTo(cx, cy, cx, cy + size * 2); // Bottom
    starPath.quadraticBezierTo(cx, cy, cx - size * 2, cy); // Left
    starPath.close();

    canvas.drawPath(starPath, sparklePaint);
  }

  @override
  bool shouldRepaint(covariant _ZenCoinPainter oldDelegate) => true;
}

