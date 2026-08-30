import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 中国铁建品牌标识（线条勾勒型：蓝经纬线 + 红 CREC + 红横带）。
/// 视觉参照官方 logo，此处为矢量自绘实现，非位图。
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 132});

  final double width;

  @override
  Widget build(BuildContext context) {
    final globeHeight = width * 0.62;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: globeHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(width, globeHeight),
                painter: const _GlobePainter(color: AppColors.brandBlue),
              ),
              Positioned(
                top: globeHeight * 0.44,
                child: Container(
                  width: width * 0.84,
                  height: globeHeight * 0.24,
                  color: AppColors.danger,
                  alignment: Alignment.center,
                  child: const Text(
                    'CREC',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '中国铁建',
          style: TextStyle(
            color: AppColors.brandBlue,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

class _GlobePainter extends CustomPainter {
  const _GlobePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final thin = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final w = size.width;
    final h = size.height;

    // 外轮廓（椭圆）
    canvas.drawOval(Rect.fromLTWH(1.5, 1.5, w - 3, h - 3), outline);

    // 两条纬线
    canvas.drawLine(Offset(0, h * 0.32), Offset(w, h * 0.32), thin);
    canvas.drawLine(Offset(0, h * 0.68), Offset(w, h * 0.68), thin);

    // 中经线（直线）
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), thin);

    // 左右弧形经线
    canvas.drawPath(
      Path()
        ..moveTo(w / 2, 2)
        ..quadraticBezierTo(w * 0.1, h / 2, w / 2, h - 2),
      thin,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w / 2, 2)
        ..quadraticBezierTo(w * 0.9, h / 2, w / 2, h - 2),
      thin,
    );
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) =>
      oldDelegate.color != color;
}
