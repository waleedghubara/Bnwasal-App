import 'dart:math';
import 'package:flutter/material.dart';
import 'package:admin_bnwasal/core/theme/colors.dart';

class SplashBackground extends StatefulWidget {
  const SplashBackground({super.key});

  @override
  State<SplashBackground> createState() => _SplashBackgroundState();
}

class _SplashBackgroundState extends State<SplashBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _particles = <_Particle>[];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _generateParticles();
  }

  void _generateParticles() {
    final random = Random();
    for (int i = 0; i < 25; i++) {
      _particles.add(_Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 3 + 1,
        opacity: random.nextDouble() * 0.4 + 0.1,
        speed: random.nextDouble() * 0.3 + 0.1,
        drift: random.nextDouble() * 2 - 1,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        painter: _ParticlePainter(_particles, _controller.value, isDark: isDark),
        size: Size.infinite,
      ),
    );
  }
}

class _Particle {
  final double x, y, size, opacity, speed, drift;
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
    required this.drift,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final bool isDark;

  _ParticlePainter(this.particles, this.progress, {required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final colorBase = isDark ? Colors.cyan : AppColors.primary;
    for (final p in particles) {
      final yPos = ((p.y + progress * p.speed) % 1.0);
      final xPos = ((p.x + sin(progress * 2 * pi + p.drift) * 0.02) % 1.0);

      final paint = Paint()
        ..color = colorBase.withValues(alpha: p.opacity * (1 - yPos * 0.5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(
        Offset(xPos * size.width, yPos * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
