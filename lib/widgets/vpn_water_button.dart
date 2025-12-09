import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum VPNState { idle, connecting, connected }

class VPNWaterButton extends StatefulWidget {
  final double size;
  final VPNState state;
  final VoidCallback onTap;

  const VPNWaterButton({
    Key? key,
    this.size = 300,
    required this.state,
    required this.onTap,
  }) : super(key: key);

  @override
  _VPNWaterButtonState createState() => _VPNWaterButtonState();
}

class _VPNWaterButtonState extends State<VPNWaterButton>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  
  // Physics Variables
  double _time = 0.0;
  double _waterLevel = 0.2; // 0.0 to 1.0
  double _targetLevel = 0.2;
  double _waveHeight = 10.0;
  double _waveSpeed = 0.02; // Initial speed slower
  
  // Color Variables
  Color _currentColor = const Color(0xFF008B8B); // Cyan
  Color _targetColor = const Color(0xFF008B8B);

  // Particles
  final List<Bubble> _bubbles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initBubbles();
    _updateTargets(); // Set initial targets based on state
    
    // Ticker runs every frame (60fps/120fps)
    _ticker = createTicker((elapsed) {
      if (mounted) {
        setState(() {
          _updatePhysics();
        });
      }
    });
    _ticker.start();
  }

  @override
  void didUpdateWidget(VPNWaterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateTargets();
    }
  }

  void _updateTargets() {
    switch (widget.state) {
      case VPNState.idle:
        _targetLevel = 0.2;
        _targetColor = const Color(0xFF008B8B); // Cyan
        _waveSpeed = 0.02; // Slower (was 0.04)
        _waveHeight = 10.0;
        break;
      case VPNState.connecting:
        _targetLevel = 0.6;
        _targetColor = const Color(0xFFFFA500); // Golden Orange
        _waveSpeed = 0.05; // Slower (was 0.15)
        _waveHeight = 15.0;
        break;
      case VPNState.connected:
        _targetLevel = 0.75;
        _targetColor = const Color(0xFF228B22); // Emerald Green
        _waveSpeed = 0.015; // Very Calm (was 0.03)
        _waveHeight = 8.0;
        break;
    }
  }

  void _initBubbles() {
    for (int i = 0; i < 12; i++) {
      _bubbles.add(Bubble(
        x: widget.size / 2,
        y: widget.size,
        radius: 2 + _random.nextDouble() * 4,
        speed: 1 + _random.nextDouble() * 2,
        offset: _random.nextDouble() * 100,
      ));
    }
  }

  void _updatePhysics() {
    _time += _waveSpeed;

    // Smooth Color Transition
    _currentColor = Color.lerp(_currentColor, _targetColor, 0.05)!;

    // Smooth Water Level Transition
    if ((_waterLevel - _targetLevel).abs() > 0.005) {
      double fillSpeed = (widget.state == VPNState.connecting) ? 0.005 : 0.03;
      _waterLevel += (_targetLevel - _waterLevel) * fillSpeed;
    }

    // Update Bubbles
    double waterY = widget.size - (widget.size * _waterLevel);
    for (var bubble in _bubbles) {
      bubble.y -= bubble.speed * (widget.state == VPNState.connecting ? 2.5 : 1.0);
      bubble.currentX = bubble.x + math.sin(_time + bubble.offset) * 5;

      // Reset bubble if it goes too high or is fully submerged too deep
      if (bubble.y < waterY || bubble.y < 0) {
        bubble.y = widget.size + 20;
        bubble.x = (widget.size / 2) + (_random.nextDouble() * widget.size * 0.5 - widget.size * 0.25);
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: CustomPaint(
          painter: WaterPainter(
            time: _time,
            waterLevel: _waterLevel,
            waveHeight: _waveHeight,
            color: _currentColor,
            bubbles: _bubbles,
          ),
        ),
      ),
    );
  }
}

// --- The Painter Logic (Canvas) ---

class WaterPainter extends CustomPainter {
  final double time;
  final double waterLevel;
  final double waveHeight;
  final Color color;
  final List<Bubble> bubbles;

  WaterPainter({
    required this.time,
    required this.waterLevel,
    required this.waveHeight,
    required this.color,
    required this.bubbles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // 1. Clip to Circle
    Path clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(clipPath);

    // 2. Draw Background (Light off-white)
    Paint bgPaint = Paint()..color = const Color(0xFFF8FAFC);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 3. Draw Water Layers
    // Back Wave (Darker, Slower)
    _drawWave(
      canvas, 
      size, 
      waterLevel - 0.05, 
      time * 0.8, 
      waveHeight * 0.8, 
      color.withOpacity(0.6),
      false
    );

    // Front Wave (Main Color, Faster)
    _drawWave(
      canvas, 
      size, 
      waterLevel, 
      time, 
      waveHeight, 
      color.withOpacity(0.9),
      true // Has Foam
    );

    // 4. Draw Bubbles
    _drawBubbles(canvas, size);

    // 5. Draw Inner Shadow (Gradient)
    _drawInnerShadow(canvas, center, radius);

    // 6. Draw Highlights (Glass Effect)
    _drawHighlights(canvas, center, radius);

    // 7. Draw Outline (Ink Style)
    Paint borderPaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawCircle(center, radius, borderPaint);
  }

  void _drawWave(Canvas canvas, Size size, double level, double phase, double amp, Color color, bool hasFoam) {
    double baseHeight = size.height * (1 - level);
    Path path = Path();
    Path foamPath = Path(); // Line for the top foam

    path.moveTo(0, size.height); // Bottom Left
    path.lineTo(0, baseHeight); // Start of wave

    // Sine Wave Loop
    for (double x = 0; x <= size.width; x++) {
      // Mix two sine waves for Japanese style irregularity
      double y = baseHeight + 
                 math.sin(x * 0.03 + phase) * amp + 
                 math.sin(x * 0.08 + phase * 2) * (amp * 0.3);
      
      path.lineTo(x, y);
      if (hasFoam) foamPath.lineTo(x, y - 4); // Slightly offset for foam
    }

    path.lineTo(size.width, size.height); // Bottom Right
    path.close();

    Paint wavePaint = Paint()..color = color;
    canvas.drawPath(path, wavePaint);

    if (hasFoam) {
      Paint foamPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawPath(foamPath, foamPaint);
    }
  }

  void _drawBubbles(Canvas canvas, Size size) {
    Paint bubblePaint = Paint()..color = Colors.white.withOpacity(0.4);
    double surfaceY = size.height * (1 - waterLevel);

    for (var b in bubbles) {
      // Only draw if inside circle roughly and under water
      double dist = (Offset(b.currentX, b.y) - Offset(size.width/2, size.height/2)).distance;
      if (dist < size.width/2 - 5 && b.y > surfaceY) {
        canvas.drawCircle(Offset(b.currentX, b.y), b.radius, bubblePaint);
      }
    }
  }

  void _drawInnerShadow(Canvas canvas, Offset center, double radius) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = RadialGradient(
      colors: [
        Colors.white.withOpacity(0.1),
        Colors.transparent,
        Colors.black.withOpacity(0.1),
      ],
      stops: const [0.0, 0.8, 1.0],
      center: const Alignment(-0.2, -0.2), // Offset slightly
    );
    
    Paint paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawHighlights(Canvas canvas, Offset center, double radius) {
    Paint highlightPaint = Paint()..color = Colors.white.withOpacity(0.85);

    // Main Kidney Highlight (Top Left)
    canvas.save();
    canvas.translate(center.dx - radius * 0.4, center.dy - radius * 0.45);
    canvas.rotate(math.pi / 4.5);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 60, height: 25), highlightPaint);
    canvas.restore();

    // Small Dot Highlight
    canvas.drawCircle(
      Offset(center.dx - radius * 0.25, center.dy - radius * 0.65), 
      6.0, 
      highlightPaint
    );

    // Rim Light (Bottom Right)
    Paint rimPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
      
    Path rimPath = Path();
    rimPath.addArc(
      Rect.fromCircle(center: center, radius: radius - 6), 
      0.2 * math.pi, 
      0.6 * math.pi
    );
    canvas.drawPath(rimPath, rimPaint);
  }

  @override
  bool shouldRepaint(covariant WaterPainter oldDelegate) {
    return true; // Always repaint for animation
  }
}

// --- Data Model for Bubbles ---
class Bubble {
  double x;
  double y;
  double currentX;
  double radius;
  double speed;
  double offset;

  Bubble({
    required this.x,
    required this.y,
    this.currentX = 0,
    required this.radius,
    required this.speed,
    required this.offset,
  });
}

