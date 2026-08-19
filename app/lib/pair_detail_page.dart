import 'package:flutter/material.dart';

import 'chart_range.dart';
import 'currencies.dart';
import 'models.dart';
import 'pair_badge.dart';
import 'rates.dart';
import 'trend_chart.dart';

class PairDetailPage extends StatefulWidget {
  const PairDetailPage({
    super.key,
    required this.quote,
    required this.client,
    this.onAlert,
  });

  final Quote quote;
  final RatesClient client;
  final VoidCallback? onAlert;

  @override
  State<PairDetailPage> createState() => _PairDetailPageState();
}

class _PairDetailPageState extends State<PairDetailPage> {
  ChartRange _range = ChartRange.w1;
  ChartSeries? _series;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(ChartRange.w1);
  }

  Future<void> _load(ChartRange range) async {
    setState(() {
      _range = range;
      _loading = true;
      _error = null;
    });
    try {
      final series = await widget.client.fetchChart(widget.quote.pair, range);
      if (!mounted) return;
      setState(() {
        _series = series;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _series = ChartSeries(
          values: widget.quote.history,
          last: widget.quote.rate,
          previousClose: widget.quote.previous,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote;
    final series = _series;
    final up = series?.up ?? (q.changePct ?? 0) >= 0;
    final green = const Color(0xFF2EE59D);
    final red = const Color(0xFFFF5C7A);
    final accent = up ? green : red;
    final sym = currencySymbol(q.pair.quote);
    final last = series?.last ?? q.rate;
    final chg = series?.change ?? ((q.previous == null) ? 0 : last - q.previous!);
    final pct = series?.changePct ?? q.changePct ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF070B16),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  _RoundIcon(icon: Icons.close, onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  _RoundIcon(icon: Icons.notifications_none, onTap: widget.onAlert),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${q.pair.base} to ${q.pair.quote}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$sym${formatRate(last)}',
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, height: 1.05, letterSpacing: -0.8),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${chg >= 0 ? '+' : ''}$sym${formatRate(chg.abs())}',
                              style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: accent, size: 22),
                            Text(
                              '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
                              style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text('· ${_range.caption}', style: const TextStyle(color: Color(0xFF9AA3C0), fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PairBadge(pair: q.pair, size: 52),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF7EE0C3)))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TrendChart(
                        values: series?.values ?? q.history,
                        up: up,
                        baseline: series?.previousClose ?? q.previous,
                        height: 280,
                      ),
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_error!, style: const TextStyle(color: Color(0xFF9AA3C0), fontSize: 11)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF12182B),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    for (final r in ChartRange.values)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _load(r),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _range == r ? const Color(0xFF2A3148) : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              r.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _range == r ? Colors.white : const Color(0xFF9AA3C0),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text(
                '图中为公开市场中间参考价，实际换汇价因买入/卖出而不同，且可能有点差。数据来自公开行情源，非投资建议。',
                style: TextStyle(color: Color(0xFF6E7690), fontSize: 11, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: Color(0xFF161C2E), shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
