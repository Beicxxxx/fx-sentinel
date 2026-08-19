import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.values,
    required this.up,
    this.baseline,
    this.height = 260,
    this.showGrid = true,
    this.strokeWidth = 2.4,
  });

  final List<double> values;
  final bool up;
  final double? baseline;
  final double height;
  final bool showGrid;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(height: height, child: const Center(child: Text('暂无走势', style: TextStyle(color: Color(0xFF9AA3C0)))));
    }
    final color = up ? const Color(0xFF2EE59D) : const Color(0xFFFF5C7A);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrendPainter(
          values: values,
          color: color,
          baseline: baseline,
          showGrid: showGrid,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.color,
    required this.baseline,
    required this.showGrid,
    required this.strokeWidth,
  });

  final List<double> values;
  final Color color;
  final double? baseline;
  final bool showGrid;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    var lo = minV;
    var hi = maxV;
    if (baseline != null) {
      lo = math.min(lo, baseline!);
      hi = math.max(hi, baseline!);
    }
    final span = (hi - lo).abs() < 1e-12 ? 1.0 : hi - lo;
    final padY = size.height * 0.08;
    Offset pt(int i, double v) {
      final x = size.width * i / (values.length - 1);
      final y = padY + (size.height - padY * 2) * (1 - (v - lo) / span);
      return Offset(x, y);
    }

    if (showGrid) {
      final grid = Paint()
        ..color = const Color(0xFF2A3148)
        ..strokeWidth = 1;
      for (var i = 0; i < 5; i++) {
        final y = size.height * i / 4;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
      for (var i = 0; i < 6; i++) {
        final x = size.width * i / 5;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
    }

    if (baseline != null) {
      final y = pt(0, baseline!).dy;
      _dash(canvas, Offset(0, y), Offset(size.width, y), const Color(0x66FFFFFF));
    }

    final points = [for (var i = 0; i < values.length; i++) pt(i, values[i])];
    final line = _smooth(points);
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (showGrid) {
      _label(canvas, Offset(8, points.first.dy - 10), formatRate(values.first));
      _label(canvas, Offset(size.width - 8, pt(0, hi).dy), formatRate(hi), alignRight: true);
      _label(canvas, Offset(size.width - 8, pt(0, lo).dy), formatRate(lo), alignRight: true);
    }
  }

  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 2) {
      path.lineTo(pts.last.dx, pts.last.dy);
      return path;
    }
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[0] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  void _dash(Canvas canvas, Offset a, Offset b, Color color) {
    const dash = 5.0;
    const gap = 4.0;
    var x = a.dx;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    while (x < b.dx) {
      canvas.drawLine(Offset(x, a.dy), Offset(math.min(x + dash, b.dx), a.dy), paint);
      x += dash + gap;
    }
  }

  void _label(Canvas canvas, Offset at, String text, {bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFFC5C9D6), fontSize: 10, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? at.dx - tp.width - 10 : at.dx;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(dx - 6, at.dy - tp.height / 2 - 4, tp.width + 12, tp.height + 8),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xE61C2236));
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values || old.color != color || old.baseline != baseline;
}
