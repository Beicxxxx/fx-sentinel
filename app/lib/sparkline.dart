import 'package:flutter/material.dart';

import 'trend_chart.dart';

class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.up});

  final List<double> values;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return TrendChart(
      values: values,
      up: up,
      height: 42,
      showGrid: false,
      strokeWidth: 1.8,
    );
  }
}
