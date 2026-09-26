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
import '../../widgets/skeleton.dart';
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

/// Keterangan, status hari ini, batas harian, batas per trade, catatan.
const _loading = SkeletonView(
  children: [
    Bone(width: 260, height: 10),
    Panel(child: SkeletonLines(lines: 3)),
    SkeletonPanel(child: SkeletonFields(count: 4)),
    SkeletonPanel(child: SkeletonFields(count: 4)),
    SkeletonPanel(child: Bone(height: 120)),
  ],
);

/// Aturan trading: catatan pribadi + indikator. Tidak ada satu pun angka di
/// sini yang memblokir pencatatan trade.
class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AccountScaffold(
    title: 'Aturan trading',
    loading: _loading,
    body: (context, account) => AsyncView(
      value: ref.watch(rulesProvider(account.id)),
      onRetry: () => ref.invalidate(rulesProvider(account.id)),
      loading: _loading,
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

class _RulesFormState extends ConsumerState<_RulesForm> {
  late final RuleSettings _rule = widget.page.rule;

  // Semua batas ditulis sebagai nominal. Aturan lama yang tersimpan dalam
  // persen ditampilkan sebagai perkiraan nominalnya; begitu disimpan, kolom
  // persennya ikut dikosongkan.
  late final _loss = _amount(_rule.maxDailyLoss, _rule.maxDailyLossPct);
  late final _target = _amount(
    _rule.dailyProfitTarget,
    _rule.dailyProfitTargetPct,
  );
  late final _risk = _amount(_rule.maxRiskPerTrade, _rule.maxRiskPerTradePct);
  late final _drawdown = _amount(_rule.maxTotalLoss, _rule.maxTotalLossPct);
  late final _minRr = TextEditingController(text: inputNumber(_rule.minRr));
  late final _maxTrades = TextEditingController(
    text: _rule.maxTradesPerDay?.toString() ?? '',
  );
  late final _notes = TextEditingController(text: _rule.notes);
  late final Set<String> _allowed = {..._rule.allowedSessions};

  bool _preview = true;
  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    for (final controller in [
      _loss,
      _target,
      _risk,
      _drawdown,
      _minRr,
      _maxTrades,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _currency => widget.account.currency;

  /// Persen lama → nominal, dihitung dari modal + dana masuk/keluar.
  TextEditingController _amount(double? amount, double? percent) {
    final basis = widget.page.basis;
    final estimate = percent != null && basis > 0
        ? (basis * percent).roundToDouble() / 100
        : null;

    return TextEditingController(text: inputNumber(amount ?? estimate));
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _errors = {};
    });

    final rule = RuleSettings(
      maxDailyLoss: parseDecimal(_loss.text),
      dailyProfitTarget: parseDecimal(_target.text),
      maxTotalLoss: parseDecimal(_drawdown.text),
      maxRiskPerTrade: parseDecimal(_risk.text),
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

  Widget _field(
    TextEditingController controller,
    String label,
    String key,
    String hint, {
    String? helper,
    bool integer = false,
    bool money = false,
  }) => TextField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    style: mono(size: 14),
    decoration: InputDecoration(
      labelText: label,
      hintText: 'Contoh: $hint',
      errorText: _errors[key],
      helperText: helper,
      suffixText: money ? _currency : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);

    return ListView(
      scrollCacheExtent: kWholePageCache,
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
              _field(
                _loss,
                'Maks. loss harian',
                'max_daily_loss',
                '100',
                money: true,
              ),
              gap,
              _field(
                _target,
                'Target profit harian',
                'daily_profit_target',
                '150',
                money: true,
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
              FieldPair(
                _field(
                  _risk,
                  'Maks. loss / trade',
                  'max_risk_per_trade',
                  '10',
                  money: true,
                ),
                _field(_minRr, 'RR minimum', 'min_rr', '2'),
                // Label dan satuan mata uang lebih panjang dari isian lain:
                // di ponsel 360 dp keduanya ditumpuk supaya tidak terpotong.
                minWidth: 150,
              ),
              gap,
              FieldPair(
                _field(
                  _maxTrades,
                  'Maks. trade / hari',
                  'max_trades_per_day',
                  '3',
                  integer: true,
                ),
                _field(
                  _drawdown,
                  'Maks. drawdown',
                  'max_total_loss',
                  '500',
                  helper: 'Dari puncak saldo trading',
                  money: true,
                ),
                minWidth: 150,
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
