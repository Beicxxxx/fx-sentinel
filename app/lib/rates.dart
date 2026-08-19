import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'models.dart';

const _host = 'https://api.frankfurter.app';

class RatesException implements Exception {
  RatesException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RatesClient {
  RatesClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();
  final http.Client _http;

  Future<List<Quote>> fetchWatchlist() async {
    final out = <Quote>[];
    for (final pair in watchlist) {
      out.add(await fetchPair(pair));
    }
    return out;
  }

  Future<Quote> fetchPair(Pair pair) async {
    final latestUri = Uri.parse('$_host/latest').replace(queryParameters: {
      'from': pair.base,
      'to': pair.quote,
    });
    final latestRes = await _http.get(latestUri);
    if (latestRes.statusCode != 200) {
      throw RatesException('行情接口返回 ${latestRes.statusCode}，请稍后重试。');
    }
    final latest = jsonDecode(latestRes.body) as Map<String, dynamic>;
    final rate = (latest['rates'][pair.quote] as num).toDouble();
    final date = latest['date'] as String;

    final start = DateTime.now().subtract(const Duration(days: 90));
    final startStr =
        '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final histUri = Uri.parse('$_host/$startStr..$date').replace(queryParameters: {
      'from': pair.base,
      'to': pair.quote,
    });
    final histRes = await _http.get(histUri);
    if (histRes.statusCode != 200) {
      return Quote(pair: pair, rate: rate, date: date);
    }
    final hist = jsonDecode(histRes.body) as Map<String, dynamic>;
    final rates = (hist['rates'] as Map<String, dynamic>? ?? {});
    final keys = rates.keys.toList()..sort();
    final points = <double>[];
    for (final k in keys) {
      final row = rates[k] as Map<String, dynamic>;
      points.add((row[pair.quote] as num).toDouble());
    }
    double? previous;
    if (points.length >= 2) previous = points[points.length - 2];
    return Quote(
      pair: pair,
      rate: rate,
      date: date,
      previous: previous,
      history: points,
    );
  }
}

Forecast baselineForecast(Quote quote) {
  final values = quote.history.isEmpty ? [quote.rate] : quote.history;
  if (values.length < 5) {
    return Forecast(
      pair: quote.pair.key,
      direction: 'range',
      confidence: 30,
      predictedChangePct: 0,
      narrative: '历史样本不足，暂按震荡处理。打开网络拉取 90 日中间价后再试。',
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
        '${quote.pair.key} 近 5 个交易日变动 ${ret5.toStringAsFixed(2)}%，相对 20 日均线 ${vsMa.toStringAsFixed(2)}%。'
        '日波动约 ${vol.toStringAsFixed(2)}%。规则基线判断未来约 7 日偏向「$dirCn」。'
        '这是对 ECB 中间价序列的外推，不含银行点差，也不是对新闻的定价。',
    risks: const [
      '日频中间价不含盘中波动与银行点差',
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
            '货币对 ${quote.pair.key} 现价 ${quote.rate} 日期 ${quote.date} 近5日涨跌 ${quote.changePct}',
      },
    ],
  };
  final res = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  ).timeout(const Duration(seconds: 40));
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
