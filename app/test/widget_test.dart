import 'package:flutter_test/flutter_test.dart';
import 'package:fx_sentinel/models.dart';
import 'package:fx_sentinel/rates.dart';
import 'package:fx_sentinel/updates.dart';

void main() {
  test('formatRate trims extra zeros', () {
    expect(formatRate(7.2), '7.2');
    expect(formatRate(147.2), '147.20');
  });

  test('version compare', () {
    expect(compareVersions('1.3.0', '1.2.0'), greaterThan(0));
    expect(compareVersions('v1.2.0', '1.2.0'), 0);
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
    expect(f.horizonDays, 7);
    expect(f.projected.length, 8);
    expect(f.chartValues.length, greaterThan(f.history.length));
    expect(f.analysis, isNotEmpty);
  });

  test('30-day forecast widens the path', () {
    final pair = defaultWatchlist.first;
    final history = [for (var i = 0; i < 40; i++) 7.0 + i * 0.01];
    final quote = Quote(pair: pair, rate: history.last, date: '2026-08-19', history: history);
    final week = baselineForecast(quote, horizonDays: 7);
    final month = baselineForecast(quote, horizonDays: 30);
    expect(month.horizonDays, 30);
    expect(month.projected.length, 31);
    expect(month.predictedChangePct.abs(), greaterThan(week.predictedChangePct.abs()));
    expect(month.confidence, lessThan(week.confidence));
  });
}
