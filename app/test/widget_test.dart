import 'package:flutter_test/flutter_test.dart';
import 'package:fx_sentinel/models.dart';
import 'package:fx_sentinel/rates.dart';

void main() {
  test('formatRate trims extra zeros', () {
    expect(formatRate(7.2), '7.2');
    expect(formatRate(147.2), '147.20');
  });

  test('yahoo symbol', () {
    expect(yahooSymbol(const Pair('USD', 'CNY')), 'USDCNY=X');
  });

  test('baseline forecast follows a climb', () {
    final pair = defaultWatchlist.first;
    final history = [for (var i = 0; i < 30; i++) 7.0 + i * 0.01];
    final quote = Quote(pair: pair, rate: history.last, date: '2026-08-19', history: history);
    final f = baselineForecast(quote);
    expect(f.direction, 'up');
    expect(f.source, 'baseline');
  });
}
