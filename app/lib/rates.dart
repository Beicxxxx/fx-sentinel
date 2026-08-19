import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'chart_range.dart';
import 'currencies.dart';
import 'models.dart';

class RatesException implements Exception {
  RatesException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RatesClient {
  RatesClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();
  final http.Client _http;

  static const _yahooHeaders = {
    'User-Agent': 'Mozilla/5.0 fx-sentinel',
    'Accept': 'application/json',
  };

  Future<List<Quote>> fetchPairs(List<Pair> pairs) async {
    final out = <Quote>[];
    for (final pair in pairs) {
      out.add(await fetchPair(pair));
    }
    return out;
  }

  Future<Quote> fetchPair(Pair pair) async {
    final labeled = Pair(pair.base, pair.quote, pairLabel(pair.base, pair.quote));
    try {
      return await _yahoo(labeled, ChartRange.w1);
    } catch (_) {
      try {
        return await _frankfurter(labeled);
      } catch (e) {
        throw RatesException('无法获取 ${pair.key}：$e');
      }
    }
  }

  Future<Quote> fetchForForecast(Pair pair, int horizonDays) async {
    final labeled = Pair(pair.base, pair.quote, pairLabel(pair.base, pair.quote));
    final range = horizonDays >= 30 ? ChartRange.m6 : ChartRange.m1;
    try {
      return await _yahoo(labeled, range);
    } catch (_) {
      return fetchPair(pair);
    }
  }

  Future<ChartSeries> fetchChart(Pair pair, ChartRange range) async {
    final q = await _yahoo(pair, range);
    return ChartSeries(
      values: _downsample(q.history, 160),
      last: q.rate,
      previousClose: q.previous,
    );
  }

  List<double> _downsample(List<double> input, int maxPoints) {
    final clean = input.where((e) => e > 0).toList();
    if (clean.length <= maxPoints) return clean;
    final step = clean.length / maxPoints;
    return [for (var i = 0; i < maxPoints; i++) clean[(i * step).floor()]];
  }

  Future<Quote> _yahoo(Pair pair, ChartRange range) async {
    final symbol = yahooSymbol(pair);
    final uri = Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/$symbol').replace(
      queryParameters: {'interval': range.interval, 'range': range.yahooRange},
    );
    final res = await _http.get(uri, headers: _yahooHeaders).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw RatesException('Yahoo HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final err = body['chart']?['error'];
    if (err != null) {
      throw RatesException(err.toString());
    }
    final results = body['chart']?['result'] as List?;
    if (results == null || results.isEmpty) {
      throw RatesException('无行情');
    }
    final result = results.first as Map<String, dynamic>;
    final meta = result['meta'] as Map<String, dynamic>;
    final price = (meta['regularMarketPrice'] as num?)?.toDouble();
    if (price == null || price <= 0) {
      throw RatesException('无有效价格');
    }
    final prev = (meta['chartPreviousClose'] as num?)?.toDouble() ??
        (meta['previousClose'] as num?)?.toDouble();
    final ts = meta['regularMarketTime'] as int?;
    final updated = ts == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final closes = <double>[];
    try {
      final quote = (((result['indicators'] as Map)['quote'] as List).first as Map)['close'] as List;
      for (final v in quote) {
        if (v is num) closes.add(v.toDouble());
      }
    } catch (_) {}
    return Quote(
      pair: pair,
      rate: price,
      date: DateFormat('MM-dd HH:mm').format(updated.toLocal()),
      previous: prev,
      history: closes.isEmpty ? [price] : closes,
      source: 'yahoo',
      updatedAt: updated,
    );
  }

  Future<Quote> _frankfurter(Pair pair) async {
    final latestUri = Uri.parse('https://api.frankfurter.app/latest').replace(queryParameters: {
      'from': pair.base,
      'to': pair.quote,
    });
    final latestRes = await _http.get(latestUri);
    if (latestRes.statusCode != 200) {
      throw RatesException('备源 HTTP ${latestRes.statusCode}');
    }
    final latest = jsonDecode(latestRes.body) as Map<String, dynamic>;
    final rates = latest['rates'] as Map<String, dynamic>?;
    final raw = rates?[pair.quote];
    if (raw is! num) {
      throw RatesException('备源不支持 ${pair.key}');
    }
    return Quote(
      pair: pair,
      rate: raw.toDouble(),
      date: latest['date'] as String? ?? '',
      source: 'ecb',
      updatedAt: DateTime.tryParse(latest['date'] as String? ?? ''),
    );
  }
}

Forecast baselineForecast(Quote quote, {int horizonDays = 7}) {
  final days = horizonDays >= 30 ? 30 : 7;
  final values = quote.history.where((e) => e > 0).toList();
  if (values.length < 5) {
    return _packForecast(
      quote: quote,
      horizonDays: days,
      direction: 'range',
      confidence: 30,
      change: 0,
      vol: 0.2,
      narrative: '历史样本不足，暂按震荡处理。',
      analysis: const ['可用收盘点过少，无法估计趋势与波动'],
      risks: const ['数据不足，情景几乎没有信息量'],
      bullCase: '补全行情后再看是否出现方向。',
      bearCase: '在样本不足时任何方向都可能立刻被打脸。',
      source: 'baseline',
    );
  }
  final last = values.last;
  final window5 = values.sublist(values.length - 5);
  final window20 = values.sublist(math.max(0, values.length - 20));
  final ret5 = (last / window5.first - 1) * 100;
  final ma20 = window20.reduce((a, b) => a + b) / window20.length;
  final vsMa = (last / ma20 - 1) * 100;
  final rets = <double>[];
  for (var i = 1; i < values.length; i++) {
    rets.add((values[i] / values[i - 1] - 1) * 100);
  }
  final mean = rets.reduce((a, b) => a + b) / rets.length;
  final vol = math.sqrt(
    rets.map((r) => (r - mean) * (r - mean)).reduce((a, b) => a + b) / rets.length,
  );
  String direction;
  double change;
  if (ret5 > 0.35 && vsMa > 0) {
    direction = 'up';
    change = math.min(ret5.abs() * 0.4, vol * 2);
  } else if (ret5 < -0.35 && vsMa < 0) {
    direction = 'down';
    change = -math.min(ret5.abs() * 0.4, vol * 2);
  } else {
    direction = 'range';
    change = 0;
  }
  var confidence = (55 - vol * 8 + vsMa.abs()).clamp(28, 62);
  if (days >= 30) {
    change *= 1.7;
    confidence = (confidence * 0.72).clamp(18, 48);
  }
  final dirCn = {'up': '上行', 'down': '下行', 'range': '震荡'}[direction]!;
  return _packForecast(
    quote: quote,
    horizonDays: days,
    direction: direction,
    confidence: confidence.round(),
    change: double.parse(change.toStringAsFixed(3)),
    vol: vol,
    narrative:
        '${quote.pair.key} 近端变动 ${ret5.toStringAsFixed(2)}%，相对均线 ${vsMa.toStringAsFixed(2)}%。'
        '波动约 ${vol.toStringAsFixed(2)}%。规则基线判断未来 $days 日偏向「$dirCn」。'
        '这不是点位预测，阴影是按历史波动外推的不确定性带。',
    analysis: [
      '近 5 个观测点收益 ${ret5 >= 0 ? '+' : ''}${ret5.toStringAsFixed(2)}%',
      '相对约 20 期均线 ${vsMa >= 0 ? '+' : ''}${vsMa.toStringAsFixed(2)}%',
      '收益波动约 ${vol.toStringAsFixed(2)}%；$days 日带宽按 √t 放大，不是保证区间',
      days >= 30 ? '30 日情景把 7 日量级大约放大 1.7 倍，并下调置信度' : '7 日只外推近端动量，遇到事件会立刻失效',
    ],
    risks: const [
      '公开行情可能有延迟，周末与节假日流动性差',
      '利率决议或风险情绪转向会立刻改写方向',
      '震荡市中趋势规则容易来回打脸',
      '没有专用「汇率大模型」，语言模型只会解说统计，不会看见未来',
    ],
    bullCase: direction == 'down'
        ? '若近端超卖后均值回归，报价可能重新贴近均线，涨幅仍受波动约束。'
        : '若动量与均线同向延续，报价有机会靠近预测中线的上沿。',
    bearCase: direction == 'up'
        ? '若动量衰竭或事件冲击，价格可能跌回均线甚至下轨。'
        : '若下跌或震荡加深，下轨以外仍可能被击穿，规则不会提前知道。',
    source: 'baseline',
  );
}

Future<Forecast> maybeLlmForecast({
  required Quote quote,
  required Forecast baseline,
  required String apiBase,
  required String apiKey,
  required String model,
}) async {
  if (apiKey.trim().isEmpty) return baseline;
  final days = baseline.horizonDays;
  final root = apiBase.trim().isEmpty ? 'https://api.openai.com/v1' : apiBase.trim();
  final uri = Uri.parse(root.endsWith('/') ? '${root}chat/completions' : '$root/chat/completions');
  final body = {
    'model': model.trim().isEmpty ? 'gpt-4o-mini' : model.trim(),
    'temperature': 0.3,
    'response_format': {'type': 'json_object'},
    'messages': [
      {'role': 'system', 'content': '只输出合法 JSON。你不是交易顾问，禁止编造新闻、央行决议或机构观点。'},
      {
        'role': 'user',
        'content':
            '根据给定统计做 $days 日汇率情景解说。输出 JSON：'
            'direction(up|down|range), confidence(0-100), predicted_change_pct, '
            'narrative(中文≤180字), analysis(字符串数组,3-5条), risks(数组), bull_case, bear_case。\n'
            '货币对 ${quote.pair.key} 现价 ${quote.rate} 时间 ${quote.date} 涨跌 ${quote.changePct}\n'
            '规则基线：方向 ${baseline.direction} 变动 ${baseline.predictedChangePct}% 置信 ${baseline.confidence}\n'
            '分析要点：${baseline.analysis.join('；')}',
      },
    ],
  };
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 40));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    return baseline;
  }
  try {
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final content = decoded['choices'][0]['message']['content'] as String;
    final parsed = jsonDecode(content) as Map<String, dynamic>;
    var direction = (parsed['direction'] as String? ?? baseline.direction).toLowerCase();
    if (direction != 'up' && direction != 'down' && direction != 'range') {
      direction = baseline.direction;
    }
    final change = (parsed['predicted_change_pct'] as num?)?.toDouble() ?? baseline.predictedChangePct;
    return _packForecast(
      quote: quote,
      horizonDays: days,
      direction: direction,
      confidence: ((parsed['confidence'] as num?)?.toInt() ?? baseline.confidence).clamp(0, 100).toInt(),
      change: change,
      vol: _impliedVol(baseline),
      narrative: (parsed['narrative'] as String?)?.trim().isNotEmpty == true
          ? (parsed['narrative'] as String).trim()
          : baseline.narrative,
      analysis: _asStrings(parsed['analysis'], baseline.analysis),
      risks: _asStrings(parsed['risks'], baseline.risks),
      bullCase: (parsed['bull_case'] as String?)?.trim().isNotEmpty == true
          ? (parsed['bull_case'] as String).trim()
          : baseline.bullCase,
      bearCase: (parsed['bear_case'] as String?)?.trim().isNotEmpty == true
          ? (parsed['bear_case'] as String).trim()
          : baseline.bearCase,
      source: 'llm',
    );
  } catch (_) {
    return baseline;
  }
}

double _impliedVol(Forecast baseline) {
  if (baseline.bandHigh.length < 2 || baseline.projected.length < 2) return 0.25;
  final last = baseline.projected.first;
  if (last == 0) return 0.25;
  return ((baseline.bandHigh[1] - baseline.projected[1]).abs() / last) * 100;
}

List<String> _asStrings(dynamic value, List<String> fallback) {
  if (value is List) {
    final items = value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).take(6).toList();
    if (items.isNotEmpty) return items;
  }
  return fallback;
}

Forecast _packForecast({
  required Quote quote,
  required int horizonDays,
  required String direction,
  required int confidence,
  required double change,
  required double vol,
  required String narrative,
  required List<String> analysis,
  required List<String> risks,
  required String bullCase,
  required String bearCase,
  required String source,
}) {
  final path = projectPath(
    history: quote.history,
    last: quote.rate,
    predictedChangePct: change,
    horizonDays: horizonDays,
    volPct: vol,
  );
  return Forecast(
    pair: quote.pair.key,
    horizonDays: horizonDays,
    direction: direction,
    confidence: confidence,
    predictedChangePct: double.parse(change.toStringAsFixed(3)),
    narrative: narrative,
    analysis: analysis,
    risks: risks,
    bullCase: bullCase,
    bearCase: bearCase,
    source: source,
    lastFmt: formatRate(quote.rate),
    lastRate: quote.rate,
    history: path.history,
    projected: path.projected,
    bandHigh: path.bandHigh,
    bandLow: path.bandLow,
  );
}

class ForecastPath {
  ForecastPath({
    required this.history,
    required this.projected,
    required this.bandHigh,
    required this.bandLow,
  });
  final List<double> history;
  final List<double> projected;
  final List<double> bandHigh;
  final List<double> bandLow;
}

ForecastPath projectPath({
  required List<double> history,
  required double last,
  required double predictedChangePct,
  required int horizonDays,
  required double volPct,
}) {
  var hist = history.where((e) => e > 0).toList();
  if (hist.isEmpty) hist = [last];
  const maxHist = 48;
  if (hist.length > maxHist) {
    hist = hist.sublist(hist.length - maxHist);
  }
  final start = hist.last;
  final target = start * (1 + predictedChangePct / 100);
  final projected = <double>[start];
  final high = <double>[start];
  final low = <double>[start];
  final dailyVol = math.max(volPct, 0.05);
  for (var i = 1; i <= horizonDays; i++) {
    final t = i / horizonDays;
    final v = start + (target - start) * t;
    final width = start * (dailyVol / 100) * math.sqrt(i.toDouble()) * 1.15;
    projected.add(v);
    high.add(v + width);
    low.add(math.max(v * 0.2, v - width));
  }
  return ForecastPath(history: hist, projected: projected, bandHigh: high, bandLow: low);
}
