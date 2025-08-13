import 'package:flutter/material.dart';
import 'dart:math';
import '../../services/theme_manager.dart';

class SineWaveAnimation extends StatefulWidget {
  const SineWaveAnimation({Key? key}) : super(key: key);

  @override
  _SineWaveAnimationState createState() => _SineWaveAnimationState();
}

class _SineWaveAnimationState extends State<SineWaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _waveMovement;
  late Animation<double> _fadeAnimation;
  
  // 监听主题变化
  late ThemeManager _themeManager;

  @override
  void initState() {
    super.initState();
    _themeManager = ThemeManager();
    _themeManager.addListener(_onThemeChanged);
    
    _initAnimation();
  }

  void _initAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    // 波的运动动画，从 -π 到 π
    _waveMovement = Tween<double>(begin: -pi, end: pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );

    // 渐显渐隐动画
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 0.2,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 0.8,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        // 主题变化时重绘
      });
    }
  }

  @override
  void dispose() {
    _themeManager.removeListener(_onThemeChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // 绘制正弦波
                CustomPaint(
                  painter: SineWavePainter(
                    waveOffset: _waveMovement.value,
                    opacity: _fadeAnimation.value,
                    themeColor: themeColor,
                  ),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                ),
                // 麦克风图标动画
                Positioned(
                  left: _controller.value * constraints.maxWidth,
                  top: constraints.maxHeight / 2 - 20,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Icon(
                      Icons.mic,
                      size: 40,
                      color: themeColor,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class SineWavePainter extends CustomPainter {
  final double waveOffset;
  final double opacity;
  final Color themeColor;

  SineWavePainter({
    required this.waveOffset,
    required this.opacity,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = themeColor.withOpacity(opacity * 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final waveHeight = min(size.height * 0.3, 40.0);
    final waveFrequency = 0.015;

    for (double x = 0; x < size.width; x++) {
      final y = size.height / 2 +
          waveHeight * sin((x * waveFrequency) + waveOffset);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
    
    // 添加第二层波浪，增加视觉效果
    final paint2 = Paint()
      ..color = themeColor.withOpacity(opacity * 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    final path2 = Path();
    final waveHeight2 = waveHeight * 0.7;
    
    for (double x = 0; x < size.width; x++) {
      final y = size.height / 2 +
          waveHeight2 * sin((x * waveFrequency * 1.5) + waveOffset + pi / 3);
      if (x == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant SineWavePainter oldDelegate) {
    return oldDelegate.waveOffset != waveOffset ||
        oldDelegate.opacity != opacity ||
        oldDelegate.themeColor != themeColor;
  }
}

const double pi = 3.1415926535897932;
