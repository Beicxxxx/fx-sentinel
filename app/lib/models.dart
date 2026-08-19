class Pair {
  const Pair(this.base, this.quote, [this.label = '']);
  final String base;
  final String quote;
  final String label;
  String get key => '$base/$quote';

  Map<String, dynamic> toJson() => {'base': base, 'quote': quote};

  factory Pair.fromJson(Map<String, dynamic> json) => Pair(
        json['base'] as String,
        json['quote'] as String,
        json['label'] as String? ?? '',
      );
}

const defaultWatchlist = <Pair>[
  Pair('USD', 'CNY', '美元 / 人民币'),
  Pair('USD', 'JPY', '美元 / 日元'),
  Pair('EUR', 'USD', '欧元 / 美元'),
  Pair('GBP', 'USD', '英镑 / 美元'),
  Pair('USD', 'HKD', '美元 / 港元'),
  Pair('AUD', 'USD', '澳元 / 美元'),
  Pair('USD', 'KRW', '美元 / 韩元'),
];

class Quote {
  Quote({
    required this.pair,
    required this.rate,
    required this.date,
    this.previous,
    this.history = const [],
    this.source = 'yahoo',
    this.updatedAt,
  });

  final Pair pair;
  final double rate;
  final String date;
  final double? previous;
  final List<double> history;
  final String source;
  final DateTime? updatedAt;

  double? get changePct {
    if (previous == null || previous == 0) return null;
    return (rate / previous! - 1) * 100;
  }
}

class Forecast {
  Forecast({
    required this.pair,
    required this.direction,
    required this.confidence,
    required this.predictedChangePct,
    required this.narrative,
    required this.risks,
    required this.source,
    required this.lastFmt,
  });

  final String pair;
  final String direction;
  final int confidence;
  final double predictedChangePct;
  final String narrative;
  final List<String> risks;
  final String source;
  final String lastFmt;
}

class AlertRule {
  AlertRule({
    required this.id,
    required this.pairKey,
    required this.above,
    required this.threshold,
    this.enabled = true,
    this.lastFiredMs,
  });

  final String id;
  final String pairKey;
  final bool above;
  final double threshold;
  bool enabled;
  int? lastFiredMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'pairKey': pairKey,
        'above': above,
        'threshold': threshold,
        'enabled': enabled,
        'lastFiredMs': lastFiredMs,
      };

  factory AlertRule.fromJson(Map<String, dynamic> json) => AlertRule(
        id: json['id'] as String,
        pairKey: json['pairKey'] as String,
        above: json['above'] as bool,
        threshold: (json['threshold'] as num).toDouble(),
        enabled: json['enabled'] as bool? ?? true,
        lastFiredMs: json['lastFiredMs'] as int?,
      );
}

String formatRate(double value) {
  if (value >= 100) return value.toStringAsFixed(2);
  if (value >= 10) return value.toStringAsFixed(4);
  final s = value.toStringAsFixed(6);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

String yahooSymbol(Pair pair) => '${pair.base}${pair.quote}=X';
