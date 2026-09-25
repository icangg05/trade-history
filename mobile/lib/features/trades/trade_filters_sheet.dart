import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/trade.dart';
import '../../widgets/common.dart';

/// Delapan filter riwayat trade. Di ponsel semuanya tidak muat di atas daftar,
/// jadi ditaruh di lembar bawah dan baru diterapkan saat tombolnya ditekan.
Future<TradeFilters?> showTradeFilters(
  BuildContext context, {
  required TradeFilters filters,
  required List<String> symbols,
  required List<String> setups,
}) => showModalBottomSheet<TradeFilters>(
  context: context,
  // Menutupi tab bar juga, sama seperti modal di web.
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      _FilterSheet(initial: filters, symbols: symbols, setups: setups),
);

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.symbols,
    required this.setups,
  });

  final TradeFilters initial;
  final List<String> symbols;
  final List<String> setups;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TradeFilters _value = widget.initial;
  late final _symbol = TextEditingController(text: widget.initial.symbol);
  late final _setup = TextEditingController(text: widget.initial.setup);
  late final _q = TextEditingController(text: widget.initial.q);

  @override
  void dispose() {
    _symbol.dispose();
    _setup.dispose();
    _q.dispose();
    super.dispose();
  }

  TradeFilters get _result => (
    symbol: _symbol.text.trim().toUpperCase(),
    setup: _setup.text.trim(),
    q: _q.text.trim(),
    status: _value.status,
    stop: _value.stop,
    direction: _value.direction,
    from: _value.from,
    to: _value.to,
  );

  Widget _choices(
    String label,
    String current,
    List<(String, String)> options,
    void Function(String) pick,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Caption(label),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (value, text) in options)
            ChoiceChip(
              label: Text(text),
              selected: current == value,
              showCheckmark: false,
              selectedColor: AppColors.gold.withValues(alpha: .15),
              labelStyle: TextStyle(
                fontSize: 12,
                color: current == value ? AppColors.gold : AppColors.foreground,
              ),
              onSelected: (_) => setState(() => pick(value)),
            ),
        ],
      ),
      const SizedBox(height: 14),
    ],
  );

  Widget _suggest(TextEditingController controller, List<String> options) =>
      options.isEmpty
      ? const SizedBox(height: 14)
      : Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 14),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final option in options)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(
                        option,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => controller.text = option),
                    ),
                  ),
              ],
            ),
          ),
        );

  Future<void> _pickDate(bool from) async {
    final current = from ? _value.from : _value.to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isEmpty ? DateTime.now() : DateTime.parse(current),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked == null) return;

    setState(() {
      final text = isoDate(picked);
      _value = from ? _copy(from: text) : _copy(to: text);
    });
  }

  TradeFilters _copy({
    String? status,
    String? stop,
    String? direction,
    String? from,
    String? to,
  }) => (
    symbol: _value.symbol,
    setup: _value.setup,
    q: _value.q,
    status: status ?? _value.status,
    stop: stop ?? _value.stop,
    direction: direction ?? _value.direction,
    from: from ?? _value.from,
    to: to ?? _value.to,
  );

  Widget _dateButton(bool from) {
    final value = from ? _value.from : _value.to;

    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _pickDate(from),
        icon: const Icon(Icons.event, size: 16),
        label: Text(
          value.isEmpty
              ? (from ? 'Dari tanggal' : 'Sampai tanggal')
              : longDate(DateTime.parse(value)),
          style: const TextStyle(fontSize: 12.5),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  // Tombol terapkan menempel di bawah lembar: delapan filter lebih tinggi
  // dari layar ponsel, dan tombol yang harus dicari dengan menggulir
  // gampang terlewat.
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            children: [
              const Text(
                'Filter trade',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _symbol,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Simbol',
                  hintText: 'XAUUSD',
                ),
              ),
              _suggest(_symbol, widget.symbols),
              TextField(
                controller: _setup,
                decoration: const InputDecoration(
                  labelText: 'Strategi',
                  hintText: 'FVG',
                ),
              ),
              _suggest(_setup, widget.setups),
              TextField(
                controller: _q,
                decoration: const InputDecoration(
                  labelText: 'Cari di catatan',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              _choices('Status', _value.status, const [
                ('', 'Semua'),
                ('win', 'Win'),
                ('loss', 'Loss'),
                ('be', 'Breakeven'),
              ], (value) => _value = _copy(status: value)),
              // Sumbu kedua: letak stop loss terhadap entry, bukan hasil trade-nya.
              _choices('Posisi stop', _value.stop, const [
                ('', 'Semua'),
                ('risk', 'Masih berisiko'),
                ('breakeven', 'BE'),
                ('sl_plus', 'SL+ profit terkunci'),
              ], (value) => _value = _copy(stop: value)),
              _choices('Arah', _value.direction, const [
                ('', 'Buy & sell'),
                ('buy', 'Buy'),
                ('sell', 'Sell'),
              ], (value) => _value = _copy(direction: value)),
              const Caption('Tanggal (hari trade ditutup)'),
              const SizedBox(height: 6),
              Row(
                children: [
                  _dateButton(true),
                  const SizedBox(width: 8),
                  _dateButton(false),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, noTradeFilters),
                child: const Text('Bersihkan'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context, _result),
                child: const Text('Terapkan'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
