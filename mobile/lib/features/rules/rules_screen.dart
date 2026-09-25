import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/account.dart';
import '../../models/journal.dart';
import '../../widgets/account_scope.dart';
import '../../widgets/common.dart';
import '../../widgets/markdown_view.dart';
import '../../widgets/rule_status_card.dart';

final rulesProvider = FutureProvider.autoDispose.family<RulesPage, int>((
  ref,
  account,
) {
  ref.watch(revisionProvider);

  return ref.watch(journalProvider).rules(account);
});

const _sessions = [
  ('sydney', 'Sydney'),
  ('tokyo', 'Tokyo'),
  ('london', 'London'),
  ('newyork', 'New York'),
];

/// Aturan trading: catatan pribadi + indikator. Tidak ada satu pun angka di
/// sini yang memblokir pencatatan trade.
class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AccountScaffold(
    title: 'Aturan trading',
    body: (context, account) => AsyncView(
      value: ref.watch(rulesProvider(account.id)),
      onRetry: () => ref.invalidate(rulesProvider(account.id)),
      // Form diisi sekali per akun; simpanan berikutnya cukup menyegarkan status.
      builder: (page) =>
          _RulesForm(key: ValueKey(account.id), account: account, page: page),
    ),
  );
}

class _RulesForm extends ConsumerStatefulWidget {
  const _RulesForm({super.key, required this.account, required this.page});

  final AccountBrief account;
  final RulesPage page;

  @override
  ConsumerState<_RulesForm> createState() => _RulesFormState();
}

/// Batas harian boleh ditulis sebagai nominal atau persen, tapi hanya salah
/// satunya. Menukar satuan mengosongkan isinya, karena angka yang sama berarti
/// hal yang berbeda di satuan yang lain.
class _Limit {
  _Limit(double? amount, double? percent)
    : pct = amount == null && percent != null,
      input = TextEditingController(text: inputNumber(amount ?? percent));

  bool pct;
  final TextEditingController input;
}

class _RulesFormState extends ConsumerState<_RulesForm> {
  late final RuleSettings _rule = widget.page.rule;

  late final _loss = _Limit(_rule.maxDailyLoss, _rule.maxDailyLossPct);
  late final _target = _Limit(
    _rule.dailyProfitTarget,
    _rule.dailyProfitTargetPct,
  );
  late final _risk = TextEditingController(
    text: inputNumber(_rule.maxRiskPerTradePct),
  );
  late final _minRr = TextEditingController(text: inputNumber(_rule.minRr));
  late final _maxTrades = TextEditingController(
    text: _rule.maxTradesPerDay?.toString() ?? '',
  );
  late final _drawdown = TextEditingController(
    text: inputNumber(_rule.maxTotalLossPct),
  );
  late final _notes = TextEditingController(text: _rule.notes);
  late final Set<String> _allowed = {..._rule.allowedSessions};

  bool _preview = true;
  bool _busy = false;
  Map<String, String> _errors = {};

  List<TextEditingController> get _controllers => [
    _loss.input,
    _target.input,
    _risk,
    _minRr,
    _maxTrades,
    _drawdown,
  ];

  @override
  void initState() {
    super.initState();

    for (final controller in _controllers) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [..._controllers, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _currency => widget.account.currency;

  /// Perkiraan nilai sebuah persentase dari modal + dana masuk/keluar.
  double? _estimate(String text) {
    final value = parseDecimal(text);
    final basis = widget.page.basis;

    return basis > 0 && value != null && value > 0 ? basis * value / 100 : null;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _errors = {};
    });

    final rule = RuleSettings(
      maxDailyLoss: _loss.pct ? null : parseDecimal(_loss.input.text),
      maxDailyLossPct: _loss.pct ? parseDecimal(_loss.input.text) : null,
      dailyProfitTarget: _target.pct ? null : parseDecimal(_target.input.text),
      dailyProfitTargetPct: _target.pct
          ? parseDecimal(_target.input.text)
          : null,
      maxTotalLossPct: parseDecimal(_drawdown.text),
      maxRiskPerTradePct: parseDecimal(_risk.text),
      maxTradesPerDay: int.tryParse(_maxTrades.text.trim()),
      minRr: parseDecimal(_minRr.text),
      allowedSessions: _allowed.toList(),
      notes: _notes.text,
    );

    try {
      final message = await ref
          .read(journalProvider)
          .saveRules(widget.account.id, rule);

      ref.read(revisionProvider.notifier).bump();
      if (mounted) showMessage(context, message);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errors = error.errors);
        showMessage(context, error.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _limitField(
    String label,
    _Limit limit,
    String amountKey,
    String pctKey,
    String example,
  ) {
    final estimate = limit.pct ? _estimate(limit.input.text) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: limit.input,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: mono(size: 14),
                decoration: InputDecoration(
                  labelText: label,
                  hintText: 'Contoh: $example',
                  errorText: _errors[limit.pct ? pctKey : amountKey],
                  helperText: estimate == null
                      ? null
                      : 'Sekitar ${money(estimate, _currency)} per hari.',
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: Segments(
                value: limit.pct,
                options: [(false, _currency), (true, '%')],
                onChanged: (value) => setState(() {
                  if (value != limit.pct) limit.input.clear();
                  limit.pct = value;
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key,
    String hint, {
    String? helper,
    bool integer = false,
  }) => TextField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    style: mono(size: 14),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: _errors[key],
      helperText: helper,
    ),
  );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    final risk = _estimate(_risk.text);
    final drawdown = _estimate(_drawdown.text);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const Caption(
          'Catatan pribadi untuk mengingat batasan sendiri. Tidak ada satu pun angka di sini yang memblokir '
          'pencatatan trade — semuanya hanya dipakai untuk menghitung sisa jatah dan menandai hari yang melanggar.',
        ),
        const SizedBox(height: 14),
        RuleStatusCard(status: widget.page.status, currency: _currency),
        const SizedBox(height: 14),
        Panel(
          title: 'Batas harian',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _limitField(
                'Maks. loss harian',
                _loss,
                'max_daily_loss',
                'max_daily_loss_pct',
                '100',
              ),
              gap,
              _limitField(
                'Target profit harian',
                _target,
                'daily_profit_target',
                'daily_profit_target_pct',
                '150',
              ),
              gap,
              Caption(
                'Perkiraan dihitung dari modal ditambah dana yang masuk, sekarang ${money(widget.page.basis, _currency)}. '
                'Saat menilai hari yang melanggar, yang dipakai adalah saldo pembukaan hari itu, jadi angkanya bisa '
                'sedikit berbeda.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Batas per trade & keseluruhan',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      _risk,
                      'Risiko / trade (%)',
                      'max_risk_per_trade_pct',
                      '1',
                      helper: risk == null
                          ? null
                          : 'Sekitar ${money(risk, _currency)}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_minRr, 'RR minimum', 'min_rr', '2')),
                ],
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      _maxTrades,
                      'Maks. trade / hari',
                      'max_trades_per_day',
                      '3',
                      integer: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _drawdown,
                      'Maks. drawdown (%)',
                      'max_total_loss_pct',
                      '10',
                      helper: drawdown == null
                          ? null
                          : 'Sekitar ${money(drawdown, _currency)}',
                    ),
                  ),
                ],
              ),
              gap,
              const Caption('Sesi yang boleh ditradingkan'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (key, label) in _sessions)
                    FilterChip(
                      label: Text(label),
                      selected: _allowed.contains(key),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: kDenseChip,
                      onSelected: (on) => setState(
                        () => on ? _allowed.add(key) : _allowed.remove(key),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          title: 'Catatan aturan',
          trailing: TextButton.icon(
            onPressed: () => setState(() => _preview = !_preview),
            icon: Icon(
              _preview ? Icons.edit_outlined : Icons.visibility_outlined,
              size: 16,
            ),
            label: Text(_preview ? 'Ubah' : 'Pratinjau'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_preview)
                MarkdownView(
                  _notes.text.trim().isEmpty
                      ? '_Belum ada catatan._'
                      : _notes.text,
                )
              else
                TextField(
                  controller: _notes,
                  minLines: 10,
                  maxLines: null,
                  style: mono(size: 12.5),
                  decoration: InputDecoration(
                    errorText: _errors['notes'],
                    hintText:
                        '## Checklist sebelum entry\n- [ ] Cek kalender news\n- [ ] Konfirmasi struktur H4\n\n'
                        '## Pantangan\n- Tidak entry setelah 2 loss beruntun',
                  ),
                ),
              const SizedBox(height: 6),
              const Caption('Mendukung markdown.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        BusyButton(
          busy: _busy,
          onPressed: _save,
          label: 'Simpan aturan',
          icon: Icons.check,
        ),
      ],
    );
  }
}
