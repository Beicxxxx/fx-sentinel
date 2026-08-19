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

Forecast baselineForecast(Quote quote) {
  final values = quote.history.where((e) => e > 0).toList();
  if (values.length < 5) {
    return Forecast(
      pair: quote.pair.key,
      direction: 'range',
      confidence: 30,
      predictedChangePct: 0,
      narrative: '历史样本不足，暂按震荡处理。',
      risks: const ['数据不足'],
      source: 'baseline',
      lastFmt: formatRate(quote.rate),
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
  final confidence = (55 - vol * 8 + vsMa.abs()).clamp(28, 62).round();
  final dirCn = {'up': '上行', 'down': '下行', 'range': '震荡'}[direction]!;
  return Forecast(
    pair: quote.pair.key,
    direction: direction,
    confidence: confidence,
    predictedChangePct: double.parse(change.toStringAsFixed(3)),
    narrative:
        '${quote.pair.key} 近端变动 ${ret5.toStringAsFixed(2)}%，相对均线 ${vsMa.toStringAsFixed(2)}%。'
        '波动约 ${vol.toStringAsFixed(2)}%。规则基线判断未来约 7 日偏向「$dirCn」。'
        '盘中报价来自公开行情源，不是银行成交价。',
    risks: const [
      '公开行情可能有延迟，周末与节假日流动性差',
      '利率决议或风险情绪转向会立刻改写方向',
      '震荡市中趋势规则容易来回打脸',
    ],
    source: 'baseline',
    lastFmt: formatRate(quote.rate),
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
  final root = apiBase.trim().isEmpty ? 'https://api.openai.com/v1' : apiBase.trim();
  final uri = Uri.parse(root.endsWith('/') ? '${root}chat/completions' : '$root/chat/completions');
  final body = {
    'model': model.trim().isEmpty ? 'gpt-4o-mini' : model.trim(),
    'temperature': 0.3,
    'response_format': {'type': 'json_object'},
    'messages': [
      {'role': 'system', 'content': '只输出合法 JSON。'},
      {
        'role': 'user',
        'content':
            '你是汇率情景解说员。只根据统计做 7 日情景，禁止编造新闻。输出 JSON：direction(up|down|range), confidence(0-100), predicted_change_pct, narrative(中文≤180字), risks(数组)。\n'
            '货币对 ${quote.pair.key} 现价 ${quote.rate} 时间 ${quote.date} 涨跌 ${quote.changePct}',
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
  final decoded = jsonDecode(res.body) as Map<String, dynamic>;
  final content = decoded['choices'][0]['message']['content'] as String;
  final parsed = jsonDecode(content) as Map<String, dynamic>;
  var direction = (parsed['direction'] as String? ?? baseline.direction).toLowerCase();
  if (direction != 'up' && direction != 'down' && direction != 'range') {
    direction = baseline.direction;
  }
  return Forecast(
    pair: quote.pair.key,
    direction: direction,
    confidence: ((parsed['confidence'] as num?)?.toInt() ?? baseline.confidence).clamp(0, 100),
    predictedChangePct: (parsed['predicted_change_pct'] as num?)?.toDouble() ?? baseline.predictedChangePct,
    narrative: (parsed['narrative'] as String?)?.trim() ?? baseline.narrative,
    risks: ((parsed['risks'] as List?)?.map((e) => e.toString()).toList() ?? baseline.risks).take(4).toList(),
    source: 'llm',
    lastFmt: baseline.lastFmt,
  );
}
