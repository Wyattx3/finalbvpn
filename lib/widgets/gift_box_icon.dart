import 'dart:math' as math;
import 'package:flutter/material.dart';

class GiftBoxIcon extends StatefulWidget {
  final double size;
  const GiftBoxIcon({super.key, required this.size});

  @override
  State<GiftBoxIcon> createState() => _GiftBoxIconState();
}

class _GiftBoxIconState extends State<GiftBoxIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
          painter: _GiftBoxPainter(_controller.value),
        );
      },
    );
  }
}

class _GiftBoxPainter extends CustomPainter {
  final double animationValue;
  _GiftBoxPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // Bouncing Physics: use abs(sin) for bounce effect
    final double time = animationValue * math.pi * 2;
    final double bounceHeight = math.sin(time).abs() * (size.height * 0.15);
    
    // Squash and Stretch
    // When hitting bottom (sin ~ 0), stretch width, shrink height
    double stretch = 1.0 + math.sin(time * 2) * 0.05;
    
    // Base dimensions
    double boxW = size.width * 0.55 * (1/stretch);
    double boxH = size.height * 0.5 * stretch;
    
    // Position
    double cy = (size.height * 0.7 - boxH/2 - bounceHeight) + (size.height * 0.1); // Moved down slightly

    // Colors
    final Paint boxColor = Paint()..color = const Color(0xFF8B5CF6); // Purple
    final Paint ribbonColor = Paint()..color = const Color(0xFFF472B6); // Pink
    final Paint shadowColor = Paint()..color = Colors.black.withOpacity(0.15);

    // 1. Draw Shadow (Grows/Shrinks with bounce)
    double shadowSize = (size.width * 0.6) * (1 - bounceHeight/(size.height * 0.4));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, (size.height * 0.85) + (size.height * 0.1)), // Moved down slightly
        width: shadowSize, 
        height: shadowSize * 0.25
      ),
      shadowColor
    );

    // 2. Draw Box Body
    Rect boxRect = Rect.fromCenter(center: Offset(cx, cy), width: boxW, height: boxH);
    canvas.drawRect(boxRect, boxColor);
    
    // Draw Box Side Shadow (Right side)
    canvas.drawRect(
      Rect.fromLTWH(cx, boxRect.top, boxW/2, boxH),
      Paint()..color = Colors.black.withOpacity(0.08)
    );

    // Vertical Ribbon on Body
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: boxW * 0.2, height: boxH),
      ribbonColor
    );

    // 3. Draw Lid
    // Lid wobbles slightly separate from body
    double lidW = boxW + (size.width * 0.1);
    double lidH = boxH * 0.25;
    double lidY = boxRect.top - lidH/2 + math.sin(time * 4) * (size.height * 0.02);
    
    Rect lidRect = Rect.fromCenter(center: Offset(cx, lidY), width: lidW, height: lidH);
    canvas.drawRect(lidRect, Paint()..color = const Color(0xFF7C3AED)); // Darker Purple
    
    // Vertical Ribbon on Lid
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, lidY), width: boxW * 0.2, height: lidH),
      ribbonColor
    );

    // 4. Draw Bow
    canvas.save();
    canvas.translate(cx, lidRect.top); // Move to top of lid
    
    // Left Loop
    Path leftBow = Path()
      ..addOval(Rect.fromCenter(center: Offset(-size.width * 0.12, -size.height * 0.04), width: size.width * 0.2, height: size.height * 0.12));
    // Right Loop
    Path rightBow = Path()
      ..addOval(Rect.fromCenter(center: Offset(size.width * 0.12, -size.height * 0.04), width: size.width * 0.2, height: size.height * 0.12));
    
    canvas.drawPath(leftBow, ribbonColor);
    canvas.drawPath(rightBow, ribbonColor);
    
    // Center Knot
    canvas.drawCircle(const Offset(0, 0), size.width * 0.05, Paint()..color = const Color(0xFFDB2777));
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GiftBoxPainter oldDelegate) => true;
}

