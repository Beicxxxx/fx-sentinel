enum ChartRange {
  d1('1D', '1d', '5m', '过去 1 天'),
  w1('1W', '5d', '15m', '过去一周'),
  m1('1M', '1mo', '1h', '过去一月'),
  m6('6M', '6mo', '1d', '过去半年'),
  y1('1Y', '1y', '1d', '过去一年'),
  y5('5Y', '5y', '1wk', '过去五年'),
  all('All', 'max', '1mo', '全部');

  const ChartRange(this.label, this.yahooRange, this.interval, this.caption);
  final String label;
  final String yahooRange;
  final String interval;
  final String caption;
}

class ChartSeries {
  ChartSeries({
    required this.values,
    required this.last,
    this.previousClose,
  });

  final List<double> values;
  final double last;
  final double? previousClose;

  double get start => values.isEmpty ? last : values.first;
  double get change => last - start;
  double get changePct => start == 0 ? 0 : (last / start - 1) * 100;
  bool get up => change >= 0;
}
