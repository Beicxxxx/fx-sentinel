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
    this.splitAt,
    this.bandHigh = const [],
    this.bandLow = const [],
  });

  final List<double> values;
  final bool up;
  final double? baseline;
  final double height;
  final bool showGrid;
  final double strokeWidth;
  final int? splitAt;
  final List<double> bandHigh;
  final List<double> bandLow;

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
          splitAt: splitAt,
          bandHigh: bandHigh,
          bandLow: bandLow,
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
    required this.splitAt,
    required this.bandHigh,
    required this.bandLow,
  });

  final List<double> values;
  final Color color;
  final double? baseline;
  final bool showGrid;
  final double strokeWidth;
  final int? splitAt;
  final List<double> bandHigh;
  final List<double> bandLow;

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
    if (bandHigh.length == values.length) {
      hi = math.max(hi, bandHigh.reduce(math.max));
    }
    if (bandLow.length == values.length) {
      lo = math.min(lo, bandLow.reduce(math.min));
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
    final cut = splitAt ?? -1;
    final hasForecast = cut > 0 && cut < values.length - 1;

    if (hasForecast && bandHigh.length == values.length && bandLow.length == values.length) {
      final cone = Path()..moveTo(points[cut].dx, pt(cut, bandHigh[cut]).dy);
      for (var i = cut; i < values.length; i++) {
        cone.lineTo(points[i].dx, pt(i, bandHigh[i]).dy);
      }
      for (var i = values.length - 1; i >= cut; i--) {
        cone.lineTo(points[i].dx, pt(i, bandLow[i]).dy);
      }
      cone.close();
      canvas.drawPath(cone, Paint()..color = color.withValues(alpha: 0.16));
    }

    final histPts = hasForecast ? points.sublist(0, cut + 1) : points;
    final line = _smooth(histPts);
    final fill = Path.from(line)
      ..lineTo(histPts.last.dx, size.height)
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

    if (hasForecast) {
      final x = points[cut].dx;
      _dash(canvas, Offset(x, 0), Offset(x, size.height), const Color(0x55FFFFFF), vertical: true);
      final fut = points.sublist(cut);
      _dashPath(canvas, _smooth(fut), color);
    }

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

  void _dash(Canvas canvas, Offset a, Offset b, Color color, {bool vertical = false}) {
    const dash = 5.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    if (vertical) {
      var y = a.dy;
      while (y < b.dy) {
        canvas.drawLine(Offset(a.dx, y), Offset(a.dx, math.min(y + dash, b.dy)), paint);
        y += dash + gap;
      }
      return;
    }
    var x = a.dx;
    while (x < b.dx) {
      canvas.drawLine(Offset(x, a.dy), Offset(math.min(x + dash, b.dx), a.dy), paint);
      x += dash + gap;
    }
  }

  void _dashPath(Canvas canvas, Path path, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      const dash = 7.0;
      const gap = 5.0;
      while (d < metric.length) {
        final next = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, next), paint);
        d = next + gap;
      }
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
      old.values != values ||
      old.color != color ||
      old.baseline != baseline ||
      old.splitAt != splitAt ||
      old.bandHigh != bandHigh ||
      old.bandLow != bandLow;
}
