import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'rates.dart';
import 'sparkline.dart';
import 'store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const FxApp());
}

const _bg = Color(0xFF0B1020);
const _card = Color(0xFF141A2E);
const _line = Color(0xFF2A3354);
const _accent = Color(0xFF7EE0C3);
const _muted = Color(0xFF9AA3C0);
const _sarasa = 'SarasaUiK';

class FxApp extends StatelessWidget {
  const FxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: _sarasa,
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        surface: _card,
      ),
    );
    return MaterialApp(
      title: '汇率哨兵',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: _sarasa, bodyColor: Colors.white, displayColor: Colors.white),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _client = RatesClient();
  final _alertStore = AlertStore();
  final _settings = SettingsStore();
  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<Quote> _quotes = [];
  List<AlertRule> _alerts = [];
  List<String> _fired = [];
  Forecast? _forecast;
  bool _forecasting = false;
  Pair _forecastPair = watchlist.first;
  Timer? _timer;

  String telegramUser = '';
  String apiKey = '';
  String apiBase = '';
  String model = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _timer = Timer.periodic(const Duration(seconds: 90), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    telegramUser = await _settings.getString('tg_user');
    apiKey = await _settings.getString('api_key');
    apiBase = await _settings.getString('api_base');
    model = await _settings.getString('model');
    _alerts = await _alertStore.load();
    await _refresh();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final quotes = await _client.fetchWatchlist();
      final fired = <String>[];
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final alert in _alerts) {
        if (!alert.enabled) continue;
        Quote? q;
        for (final item in quotes) {
          if (item.pair.key == alert.pairKey) q = item;
        }
        if (q == null) continue;
        final hit = alert.above ? q.rate >= alert.threshold : q.rate <= alert.threshold;
        if (!hit) continue;
        if (alert.lastFiredMs != null && now - alert.lastFiredMs! < AlertStore.cooldownMs) {
          continue;
        }
        alert.lastFiredMs = now;
        final cond = alert.above ? '高于' : '低于';
        fired.add('${alert.pairKey} 现价 ${formatRate(q.rate)} 已$cond ${formatRate(alert.threshold)}');
      }
      if (fired.isNotEmpty) await _alertStore.save(_alerts);
      setState(() {
        _quotes = quotes;
        _loading = false;
        _error = null;
        _fired = [...fired, ..._fired].take(12).toList();
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _runForecast() async {
    Quote? quote;
    for (final q in _quotes) {
      if (q.pair.key == _forecastPair.key) quote = q;
    }
    setState(() => _forecasting = true);
    try {
      quote ??= await _client.fetchPair(_forecastPair);
      final baseline = baselineForecast(quote);
      final result = await maybeLlmForecast(
        quote: quote,
        baseline: baseline,
        apiBase: apiBase,
        apiKey: apiKey,
        model: model,
      );
      setState(() {
        _forecast = result;
        _forecasting = false;
      });
    } catch (e) {
      setState(() => _forecasting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('预测失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(onRefresh: () => _refresh()),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _RatesTab(
                    loading: _loading,
                    error: _error,
                    quotes: _quotes,
                    onRetry: () => _refresh(),
                    onForecast: (pair) {
                      setState(() {
                        _forecastPair = pair;
                        _tab = 2;
                      });
                      _runForecast();
                    },
                    onAlert: (pair, rate) => _showAddAlert(pair, rate),
                  ),
                  _AlertsTab(
                    alerts: _alerts,
                    fired: _fired,
                    telegramUser: telegramUser,
                    onAdd: () {
                      if (_quotes.isEmpty) return;
                      _showAddAlert(_quotes.first.pair, _quotes.first.rate);
                    },
                    onDelete: (id) async {
                      setState(() => _alerts.removeWhere((a) => a.id == id));
                      await _alertStore.save(_alerts);
                    },
                    onToggle: (id, v) async {
                      for (final a in _alerts) {
                        if (a.id == id) a.enabled = v;
                      }
                      setState(() {});
                      await _alertStore.save(_alerts);
                    },
                    onOpenTelegram: _openTelegram,
                  ),
                  _ForecastTab(
                    pair: _forecastPair,
                    forecasting: _forecasting,
                    forecast: _forecast,
                    onPick: (p) => setState(() => _forecastPair = p),
                    onRun: _runForecast,
                    hasKey: apiKey.trim().isNotEmpty,
                  ),
                  _SettingsTab(
                    telegramUser: telegramUser,
                    apiKey: apiKey,
                    apiBase: apiBase,
                    model: model,
                    onSave: (tg, key, base, mdl) async {
                      telegramUser = tg;
                      apiKey = key;
                      apiBase = base;
                      model = mdl;
                      await _settings.setString('tg_user', tg);
                      await _settings.setString('api_key', key);
                      await _settings.setString('api_base', base);
                      await _settings.setString('model', mdl);
                      if (!context.mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已保存。预警推送仍由电脑上的 Telegram 机器人负责。')),
                      );
                    },
                  ),
                ],
              ),
            ),
            _Nav(index: _tab, onTap: (i) => setState(() => _tab = i)),
          ],
        ),
      ),
    );
  }

  Future<void> _openTelegram() async {
    final user = telegramUser.trim().replaceFirst('@', '');
    final uri = user.isEmpty
        ? Uri.parse('https://t.me')
        : Uri.parse('https://t.me/$user');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showAddAlert(Pair pair, double rate) async {
    var selected = pair;
    var above = false;
    final controller = TextEditingController(text: formatRate(rate));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('新建阈值预警', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('应用内会检查；可靠推送请在 Telegram 里再设一条 /watch。', style: TextStyle(color: _muted, fontSize: 12)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<Pair>(
                    initialValue: selected,
                    dropdownColor: _card,
                    items: [
                      for (final p in watchlist)
                        DropdownMenuItem(value: p, child: Text('${p.key}  ${p.label}')),
                    ],
                    onChanged: (v) => setLocal(() => selected = v ?? selected),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('低于'),
                        selected: !above,
                        onSelected: (_) => setLocal(() => above = false),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('高于'),
                        selected: above,
                        onSelected: (_) => setLocal(() => above = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '阈值（中间价）'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('保存'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (ok != true) return;
    final threshold = double.tryParse(controller.text.trim());
    if (threshold == null) return;
    final rule = AlertRule(
      id: DateTime.now().millisecondsSinceEpoch.toRadixString(16),
      pairKey: selected.key,
      above: above,
      threshold: threshold,
    );
    setState(() => _alerts = [..._alerts, rule]);
    await _alertStore.save(_alerts);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('汇率哨兵', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                Text('ECB 中间价 · 非银行柜台成交价', style: TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded), color: _accent),
        ],
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    Widget item(int i, IconData icon, String label) {
      final on = index == i;
      return Expanded(
        child: InkWell(
          onTap: () => onTap(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: on ? _accent : _muted),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 11, color: on ? _accent : _muted)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))),
      child: Row(
        children: [
          item(0, Icons.stacked_line_chart, '行情'),
          item(1, Icons.notifications_active_outlined, '预警'),
          item(2, Icons.auto_awesome, '预测'),
          item(3, Icons.tune, '设置'),
        ],
      ),
    );
  }
}

class _RatesTab extends StatelessWidget {
  const _RatesTab({
    required this.loading,
    required this.error,
    required this.quotes,
    required this.onRetry,
    required this.onForecast,
    required this.onAlert,
  });

  final bool loading;
  final String? error;
  final List<Quote> quotes;
  final VoidCallback onRetry;
  final void Function(Pair) onForecast;
  final void Function(Pair, double) onAlert;

  @override
  Widget build(BuildContext context) {
    if (loading && quotes.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    if (error != null && quotes.isEmpty) {
      return _Empty(
        title: '行情暂时拉不到',
        detail: error!,
        action: '重试',
        onAction: onRetry,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: quotes.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 10, left: 4),
            child: Text('欧洲央行日频中间价，通常滞后一个交易日。', style: TextStyle(color: _muted, fontSize: 12)),
          );
        }
        final q = quotes[i - 1];
        final up = (q.changePct ?? 0) >= 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.pair.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(q.pair.label, style: const TextStyle(color: _muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatRate(q.rate), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      Text(
                        q.changePct == null ? q.date : '${q.changePct! >= 0 ? '+' : ''}${q.changePct!.toStringAsFixed(2)}%  ·  ${q.date}',
                        style: TextStyle(color: up ? const Color(0xFF3DDC97) : const Color(0xFFFF8A8A), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Sparkline(values: q.history, up: up),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(onPressed: () => onForecast(q.pair), child: const Text('7 日情景')),
                  TextButton(onPressed: () => onAlert(q.pair, q.rate), child: const Text('设预警')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AlertsTab extends StatelessWidget {
  const _AlertsTab({
    required this.alerts,
    required this.fired,
    required this.telegramUser,
    required this.onAdd,
    required this.onDelete,
    required this.onToggle,
    required this.onOpenTelegram,
  });

  final List<AlertRule> alerts;
  final List<String> fired;
  final String telegramUser;
  final VoidCallback onAdd;
  final void Function(String) onDelete;
  final void Function(String, bool) onToggle;
  final VoidCallback onOpenTelegram;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _HintCard(
          title: '可靠推送走 Telegram',
          body: '手机休眠后应用内检查不稳定。在电脑运行机器人后发送 /start，再用 /watch USD/CNY below 7.10。',
          action: telegramUser.trim().isEmpty ? '打开 Telegram' : '打开 @${telegramUser.replaceFirst('@', '')}',
          onAction: onOpenTelegram,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Text('应用内规则', style: TextStyle(fontWeight: FontWeight.w700))),
            FilledButton.tonal(onPressed: onAdd, child: const Text('添加')),
          ],
        ),
        const SizedBox(height: 8),
        if (alerts.isEmpty)
          const _Empty(
            title: '还没有预警',
            detail: '例如：美元兑人民币中间价低于你的心理价位时提醒。',
          ),
        for (final a in alerts)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${a.pairKey}  ${a.above ? '高于' : '低于'}  ${formatRate(a.threshold)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(value: a.enabled, onChanged: (v) => onToggle(a.id, v)),
                IconButton(onPressed: () => onDelete(a.id), icon: const Icon(Icons.delete_outline, size: 20)),
              ],
            ),
          ),
        if (fired.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('最近触发', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final line in fired)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line, style: const TextStyle(color: _accent, fontSize: 13)),
            ),
        ],
      ],
    );
  }
}

class _ForecastTab extends StatelessWidget {
  const _ForecastTab({
    required this.pair,
    required this.forecasting,
    required this.forecast,
    required this.onPick,
    required this.onRun,
    required this.hasKey,
  });

  final Pair pair;
  final bool forecasting;
  final Forecast? forecast;
  final void Function(Pair) onPick;
  final VoidCallback onRun;
  final bool hasKey;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    final dir = f == null ? '' : {'up': '上行', 'down': '下行', 'range': '震荡'}[f.direction] ?? f.direction;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(hasKey ? '将调用你配置的大模型；失败时回退规则基线。' : '未配置密钥，使用规则基线（均线与波动率）。', style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 12),
        DropdownButtonFormField<Pair>(
          initialValue: pair,
          dropdownColor: _card,
          items: [for (final p in watchlist) DropdownMenuItem(value: p, child: Text('${p.key}  ${p.label}'))],
          onChanged: (v) {
            if (v != null) onPick(v);
          },
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: forecasting ? null : onRun,
          child: Text(forecasting ? '正在推演…' : '生成 7 日情景'),
        ),
        const SizedBox(height: 16),
        if (forecasting) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: _accent))),
        if (f != null && !forecasting)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${f.pair} · $dir', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  '置信度 ${f.confidence}%　预估 ${f.predictedChangePct >= 0 ? '+' : ''}${f.predictedChangePct.toStringAsFixed(2)}%　现价 ${f.lastFmt}',
                  style: const TextStyle(color: _accent),
                ),
                const SizedBox(height: 4),
                Text(f.source == 'llm' ? '来源：大模型情景' : '来源：规则基线', style: const TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 12),
                Text(f.narrative, style: const TextStyle(height: 1.45)),
                const SizedBox(height: 12),
                const Text('风险', style: TextStyle(fontWeight: FontWeight.w700)),
                for (final r in f.risks)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('· $r', style: const TextStyle(color: _muted)),
                  ),
                const SizedBox(height: 12),
                const Text(
                  '仅供学习研究，不构成投资、换汇或交易建议。',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        if (f == null && !forecasting)
          const _Empty(title: '还没有情景', detail: '选一个货币对，把近 90 日中间价压成方向、置信度与风险说明。'),
      ],
    );
  }
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({
    required this.telegramUser,
    required this.apiKey,
    required this.apiBase,
    required this.model,
    required this.onSave,
  });

  final String telegramUser;
  final String apiKey;
  final String apiBase;
  final String model;
  final void Function(String, String, String, String) onSave;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late final _tg = TextEditingController(text: widget.telegramUser);
  late final _key = TextEditingController(text: widget.apiKey);
  late final _base = TextEditingController(text: widget.apiBase);
  late final _model = TextEditingController(text: widget.model.isEmpty ? 'gpt-4o-mini' : widget.model);

  @override
  void dispose() {
    _tg.dispose();
    _key.dispose();
    _base.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const Text('机器人用户名', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _tg,
          decoration: const InputDecoration(hintText: '例如 my_fx_bot（不要带 t.me）'),
        ),
        const SizedBox(height: 14),
        const Text('大模型（可选）', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _key,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'OPENAI_API_KEY，留空则用规则基线'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _base,
          decoration: const InputDecoration(hintText: '兼容网关，默认 api.openai.com/v1'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _model,
          decoration: const InputDecoration(hintText: '模型名'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => widget.onSave(_tg.text.trim(), _key.text.trim(), _base.text.trim(), _model.text.trim()),
          child: const Text('保存设置'),
        ),
        const SizedBox(height: 20),
        const Text(
          '字体为更纱黑体 UI K（韩文地区字形，SIL OFL 1.1），界面汉字可能与简体国标略有差异。行情来自 Frankfurter / 欧洲央行。',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
        ),
      ],
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.title, required this.body, required this.action, required this.onAction});
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF17302C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2F5E56)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: _muted, height: 1.4, fontSize: 13)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onAction, child: Text(action)),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.detail, this.action, this.onAction});
  final String title;
  final String detail;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.4)),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
