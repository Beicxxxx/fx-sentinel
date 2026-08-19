import unittest
from fx_sentinel.alerts import evaluate
from fx_sentinel.predict import baseline_forecast, summarize
from fx_sentinel.rates import Pair, Quote, Series, format_rate, parse_pair
from fx_sentinel.store import Alert, Store
from pathlib import Path
import tempfile


class ParsePairTest(unittest.TestCase):
    def test_known(self):
        p = parse_pair("usd-cny")
        self.assertEqual(p.key, "USD/CNY")
        self.assertIn("人民币", p.label)

    def test_custom(self):
        p = parse_pair("NZD/USD")
        self.assertEqual(p.base, "NZD")


class FormatTest(unittest.TestCase):
    def test_jpy(self):
        self.assertEqual(format_rate(147.23), "147.23")


class ForecastTest(unittest.TestCase):
    def test_uptrend(self):
        pair = Pair("USD", "CNY", "美元/人民币")
        points = [(f"2026-01-{i:02d}", 7.0 + i * 0.01) for i in range(1, 28)]
        stats = summarize(Series(pair, points))
        f = baseline_forecast(pair, stats)
        self.assertEqual(f.direction, "up")
        self.assertEqual(f.source, "baseline")


class AlertTest(unittest.TestCase):
    def test_fires_below(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = Store(Path(tmp) / "s.json")
            store.data.alerts.append(
                Alert(id="a1", pair="USD/CNY", condition="below", threshold=7.2, cooldown_hours=0)
            )
            pair = parse_pair("USD/CNY")
            events = evaluate(store, [Quote(pair=pair, rate=7.15, date="2026-08-19")])
            self.assertEqual(len(events), 1)
            events2 = evaluate(store, [Quote(pair=pair, rate=7.15, date="2026-08-19")])
            self.assertEqual(len(events2), 1)


if __name__ == "__main__":
    unittest.main()
