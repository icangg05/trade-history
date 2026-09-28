import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/json.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/trade.dart';
import '../../widgets/common.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/setup_picker.dart';
import 'ai_import_sheet.dart';

/// Keterangan, tombol isi dari screenshot, lalu kartu simbol & arah, harga,
/// hasil, dan setup.
const _loading = SkeletonView(
  children: [
    Bone(width: 260, height: 10),
    SkeletonField(),
    Panel(child: SkeletonFields()),
    Panel(child: SkeletonFields(count: 3)),
    Panel(child: SkeletonFields(count: 2)),
    SkeletonPanel(child: Bone(height: 60)),
  ],
);

final _formProvider = FutureProvider.autoDispose
    .family<(Trade?, bool, List<String>), (int, String?)>(
      (ref, key) => ref.watch(journalProvider).tradeForm(key.$1, key.$2),
    );

/// Catat trade baru atau ubah yang lama. Isi manual, atau biarkan AI membaca
/// screenshot lalu koreksi hasilnya — AI cuma pengisi awal, validasinya sama
/// persis dengan input manual (`TradeRequest`).
class TradeFormScreen extends ConsumerWidget {
  const TradeFormScreen({super.key, this.tradeId});

  final String? tradeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentAccountProvider).value;

    final loading = Scaffold(
      key: const ValueKey('loading'),
      appBar: AppBar(),
      body: _loading,
    );

    if (account == null) return FadeSwitch(child: loading);

    final key = (account.id, tradeId);

    return FadeSwitch(
      child: ref
          .watch(_formProvider(key))
          .when(
            loading: () => loading,
            error: (error, _) => Scaffold(
              key: const ValueKey('error'),
              appBar: AppBar(),
              body: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(_formProvider(key)),
              ),
            ),
            data: (data) => _TradeForms(
              account: account.id,
              currency: account.currency,
              trade: data.$1,
              aiEnabled: data.$2,
              symbols: data.$3,
            ),
          ),
    );
  }
}

/// Satu tab per trade. Biasanya hanya satu, tanpa tab; tab muncul setelah
/// beberapa screenshot dibaca sekaligus, supaya form tidak menumpuk ke bawah.
class _TradeForms extends ConsumerStatefulWidget {
  const _TradeForms({
    required this.account,
    required this.currency,
    required this.trade,
    required this.aiEnabled,
    required this.symbols,
  });

  final int account;
  final String currency;
  final Trade? trade;
  final bool aiEnabled;
  final List<String> symbols;

  @override
  ConsumerState<_TradeForms> createState() => _TradeFormsState();
}

class _TradeFormsState extends ConsumerState<_TradeForms>
    with TickerProviderStateMixin {
  /// Kunci tiap tab plus hasil AI pengisi awalnya. IndexedStack menjaga isian
  /// tab yang sedang tidak terlihat; kuncinya dipakai untuk menyimpan semuanya.
  List<(GlobalKey<_TradeFormState>, AiImport?)> _forms = [(GlobalKey(), null)];
  TabController? _tabs;
  bool _busy = false;

  int get _index => _tabs?.index ?? 0;

  void _setForms(
    List<(GlobalKey<_TradeFormState>, AiImport?)> forms,
    int index,
  ) {
    // Dilepas setelah bingkai ini: TabBar lama masih memegangnya sampai dibangun ulang.
    final old = _tabs;
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());

    _forms = forms;
    _tabs = forms.length < 2
        ? null
        : (TabController(length: forms.length, vsync: this, initialIndex: index)
            ..addListener(() => setState(() {})));
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  /// Screenshot pertama mengisi tab ini; sisanya jadi tab baru tepat di
  /// belakangnya. Jumlah tab tidak pernah melebihi [maxScreenshots].
  Future<void> _import() async {
    final picked = await showAiImport(
      context,
      widget.account,
      max: maxScreenshots - _forms.length + 1,
    );

    if (picked == null || picked.isEmpty || !mounted) return;

    final at = _index;

    _forms[at].$1.currentState!.fill(picked.first);

    if (picked.length > 1) {
      setState(
        () => _setForms([
          ..._forms.take(at + 1),
          for (final result in picked.skip(1)) (GlobalKey(), result),
          ..._forms.skip(at + 1),
        ], at),
      );
      showMessage(
        context,
        '${picked.length} screenshot terbaca, satu tab per trade. Periksa tiap tab sebelum menyimpan.',
      );
    }
  }

  Future<void> _discard() async {
    final at = _index;

    if (!await confirm(
          context,
          title: 'Buang Trade ${at + 1}?',
          message: 'Isian di tab ini hilang dan tidak ikut disimpan.',
          action: 'Buang',
          destructive: true,
        ) ||
        !mounted) {
      return;
    }

    setState(
      () =>
          _setForms([..._forms]..removeAt(at), at.clamp(0, _forms.length - 2)),
    );
  }

  Future<void> _save() async {
    // Diambil di awal: daftar trade tetap disegarkan walau layar ini sudah
    // ditutup sebelum semua tab selesai tersimpan.
    final revision = ref.read(revisionProvider.notifier);

    setState(() => _busy = true);

    var saved = 0;
    String? done;
    String? failure;

    // Berurutan dari tab pertama. Yang sudah tersimpan langsung keluar dari
    // daftar, jadi menyimpan ulang setelah memperbaiki satu tab tidak
    // menggandakan trade lainnya.
    try {
      while (true) {
        final message = await _forms.first.$1.currentState!.submit();

        if (message == null) break;

        saved++;

        if (_forms.length == 1) {
          done = message;
          break;
        }

        if (!mounted) break;

        setState(() => _setForms(_forms.sublist(1), 0));
      }
    } on ApiException catch (error) {
      failure = error.message;
    }

    if (saved > 0) revision.bump();

    if (!mounted) return;

    setState(() => _busy = false);

    if (done != null) {
      showMessage(context, saved == 1 ? done : '$saved trade dicatat.');
      // Trade baru selalu berakhir di daftar trade, dari mana pun tombol +
      // ditekan. Mengubah trade kembali ke tempat asalnya.
      widget.trade == null ? context.go('/trades') : context.pop();

      return;
    }

    // Yang gagal selalu tab pertama yang tersisa.
    _tabs?.animateTo(0);

    final prefix = saved == 0 ? '' : '$saved trade tersimpan. ';

    if (failure != null) {
      showMessage(context, '$prefix$failure', error: true);
    } else if (saved > 0) {
      showMessage(
        context,
        '${prefix}Perbaiki tab yang tersisa lalu simpan lagi.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _forms.length > 1
        ? 'Simpan ${_forms.length} trade'
        : 'Simpan';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trade != null ? 'Ubah trade' : 'Trade baru'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('Simpan'),
          ),
          const SizedBox(width: 4),
        ],
        bottom: _tabs == null
            ? null
            : TabBar(
                controller: _tabs,
                tabs: [
                  for (var i = 0; i < _forms.length; i++)
                    Tab(text: 'Trade ${i + 1}'),
                ],
              ),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          for (final (key, initial) in _forms)
            _TradeForm(
              key: key,
              account: widget.account,
              currency: widget.currency,
              trade: widget.trade,
              aiEnabled: widget.aiEnabled,
              symbols: widget.symbols,
              initial: initial,
              busy: _busy,
              saveLabel: label,
              onSave: _save,
              onImport: _import,
              onDiscard: _forms.length > 1 ? _discard : null,
            ),
        ],
      ),
    );
  }
}

/// Isian satu trade. Tombol dan aksi yang menyangkut semua tab (simpan,
/// import, buang tab) dipegang [_TradeForms].
class _TradeForm extends ConsumerStatefulWidget {
  const _TradeForm({
    super.key,
    required this.account,
    required this.currency,
    required this.trade,
    required this.aiEnabled,
    required this.symbols,
    required this.initial,
    required this.busy,
    required this.saveLabel,
    required this.onSave,
    required this.onImport,
    required this.onDiscard,
  });

  final int account;
  final String currency;
  final Trade? trade;
  final bool aiEnabled;
  final List<String> symbols;

  /// Hasil AI yang mengisi tab ini sejak dibuka — tab kedua dan seterusnya.
  final AiImport? initial;

  final bool busy;
  final String saveLabel;
  final VoidCallback onSave;
  final VoidCallback onImport;

  /// Null kalau hanya ada satu tab.
  final VoidCallback? onDiscard;

  @override
  ConsumerState<_TradeForm> createState() => _TradeFormState();
}

class _TradeFormState extends ConsumerState<_TradeForm> {
  late final Trade? _trade = widget.trade;

  late final _symbol = TextEditingController(text: _trade?.symbol ?? '');
  late final _lot = TextEditingController(text: inputNumber(_trade?.lot));
  late final _entry = TextEditingController(
    text: inputNumber(_trade?.entryPrice),
  );
  late final _sl = TextEditingController(text: inputNumber(_trade?.slPrice));
  late final _tp = TextEditingController(text: inputNumber(_trade?.tpPrice));
  late final _exit = TextEditingController(
    text: inputNumber(_trade?.exitPrice),
  );
  late final _pnl = TextEditingController(
    text: _trade == null ? '' : inputNumber(_trade.pnl),
  );
  late final _notes = TextEditingController(text: _trade?.notes ?? '');

  late String _direction = _trade?.direction ?? 'buy';
  late DateTime _openedAt = _trade?.openedAt ?? DateTime.now();
  late DateTime? _closedAt = _trade?.closedAt;
  late String _setup = _trade?.setup ?? '';
  late String _source = _trade?.source ?? 'manual';

  /// Jejak apa yang dibaca AI dari gambar. Gambarnya tidak disimpan, jadi ini
  /// satu-satunya cara memeriksa ulang kalau angkanya nanti terasa janggal.
  late Json? _aiRaw = _trade?.aiRaw;

  /// Field yang barusan diisi AI — ditandai supaya diperiksa dulu.
  Set<String> _aiFields = {};
  List<String> _lowConfidence = [];
  Uint8List? _aiPreview;

  Map<String, String> _errors = {};

  bool get _editing => _trade != null;

  /// Setup dan catatan milik grup, bukan milik satu trade — dikunci di sini.
  bool get _inGroup => _trade?.groupId != null;

  List<TextEditingController> get _numbers => [
    _lot,
    _entry,
    _sl,
    _tp,
    _exit,
    _pnl,
  ];

  @override
  void initState() {
    super.initState();

    // Sebelum pendengarnya dipasang: mengisi teks memicu setState, dan
    // setState belum boleh dipanggil di sini.
    if (widget.initial case final picked?) _apply(picked);

    for (final controller in [..._numbers, _symbol]) {
      controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    for (final controller in [..._numbers, _symbol, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed() {
    // Waktu tutup wajib diisi: begitu hasilnya diketik, disamakan dengan waktu
    // buka supaya tidak perlu diisi ulang untuk trade intraday.
    if (_pnl.text.trim().isNotEmpty && _closedAt == null) _closedAt = _openedAt;

    setState(() {});
  }

  double? get _e => parseDecimal(_entry.text);
  double? get _stop => parseDecimal(_sl.text);
  double? get _target => parseDecimal(_tp.text);

  bool get _stopOnLossSide {
    final e = _e;
    final sl = _stop;

    return e != null && sl != null && (_direction == 'buy' ? sl < e : sl > e);
  }

  /// RR rencana dihitung ulang di sini hanya untuk umpan balik langsung;
  /// nilai yang tersimpan tetap dihitung server.
  double? get _plannedRr {
    final (e, sl, tp) = (_e, _stop, _target);

    if (e == null || sl == null || tp == null || !_stopOnLossSide) return null;

    return (tp - e).abs() / (e - sl).abs();
  }

  /// Stop yang digeser ke entry atau melewatinya bukan kesalahan — itu
  /// break-even / SL+. Yang tampil keterangan, bukan pesan galat.
  String? get _stopNote {
    final (e, sl) = (_e, _stop);

    if (e == null || sl == null || _stopOnLossSide) return null;

    if (sl == e) {
      return 'Stop loss persis di harga entry, jadi posisi break-even dan risiko sudah nol. Nilai R tidak dihitung.';
    }

    return 'Stop loss ${_direction == 'buy' ? 'di atas' : 'di bawah'} entry (SL+). Sebagian profit sudah dikunci, '
        'jadi posisi tidak bisa rugi lagi. Nilai R tidak dihitung.';
  }

  bool get _tpSideWrong {
    final (e, tp) = (_e, _target);

    return e != null && tp != null && (_direction == 'buy' ? tp < e : tp > e);
  }

  String? _badge(String field) {
    if (_lowConfidence.contains(field)) return 'AI ragu, periksa lagi';

    return _aiFields.contains(field) ? 'Diisi AI' : null;
  }

  /// Isi tab ini dari hasil baca AI.
  void fill(AiImport picked) => setState(() => _apply(picked));

  void _apply(AiImport picked) {
    final data = picked.result.data;
    final filled = <String>{};
    final controllers = {
      'symbol': _symbol,
      'lot': _lot,
      'entry_price': _entry,
      'sl_price': _sl,
      'tp_price': _tp,
      'exit_price': _exit,
      'pnl': _pnl,
      'notes': _notes,
    };

    for (final MapEntry(:key, :value) in data.entries) {
      if (value == null || '$value'.isEmpty) continue;

      switch (key) {
        case 'direction':
          _direction = '$value';
        case 'opened_at':
          _openedAt = wallTime('$value');
        case 'closed_at':
          _closedAt = wallTime('$value');
        case 'setup':
          _setup = '$value';
        default:
          final controller = controllers[key];
          if (controller == null) continue;
          controller.text = value is num
              ? inputNumber(value.toDouble())
              : '$value';
      }

      filled.add(key);
    }

    _source = 'ai';
    _aiRaw = picked.result.raw;
    _aiFields = filled;
    _lowConfidence = picked.result.lowConfidence;
    _aiPreview = picked.image;
    _errors = {};
  }

  Future<void> _pickTime({required bool closed}) async {
    final current = closed ? (_closedAt ?? _openedAt) : _openedAt;

    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );

    if (time == null) return;

    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() => closed ? _closedAt = value : _openedAt = value);
  }

  /// Simpan trade di tab ini. Pesan server kalau berhasil; null kalau
  /// isiannya ditolak — galatnya tampil di field masing-masing. Galat lain
  /// (jaringan, server) dilempar ke [_TradeForms].
  Future<String?> submit() async {
    // Angka yang tidak terbaca ditolak di sini; mengirim null diam-diam akan
    // berakhir sebagai pesan "wajib diisi" yang membingungkan.
    final invalid = {
      ...requiredErrors({
        'symbol': _symbol.text,
        'entry_price': _entry.text,
        'pnl': _pnl.text,
      }),
      if (_closedAt == null) 'closed_at': 'Wajib diisi.',
      for (final (key, controller) in [
        ('lot', _lot),
        ('entry_price', _entry),
        ('sl_price', _sl),
        ('tp_price', _tp),
        ('exit_price', _exit),
        ('pnl', _pnl),
      ])
        if (controller.text.trim().isNotEmpty &&
            parseDecimal(controller.text) == null)
          key: 'Angka tidak valid.',
    };

    if (invalid.isNotEmpty) {
      setState(() => _errors = invalid);
      return null;
    }

    setState(() => _errors = {});

    try {
      return await ref
          .read(journalProvider)
          .saveTrade(widget.account, _trade?.id, {
            'symbol': _symbol.text.trim().toUpperCase(),
            'direction': _direction,
            'lot': parseDecimal(_lot.text),
            'entry_price': _e,
            'sl_price': _stop,
            'tp_price': _target,
            'exit_price': parseDecimal(_exit.text),
            'pnl': parseDecimal(_pnl.text),
            'opened_at': isoMinute(_openedAt),
            'closed_at': _closedAt == null ? null : isoMinute(_closedAt!),
            'setup': _setup,
            'notes': _notes.text,
            'source': _source,
            'ai_raw': _aiRaw,
          });
    } on ApiException catch (error) {
      if (error.errors.isEmpty) rethrow;
      if (mounted) setState(() => _errors = error.errors);

      return null;
    }
  }

  Widget _number(
    TextEditingController controller,
    String label,
    String key, {
    String? hint,
    bool required = false,
    bool signed = false,
    String? note,
    Color noteColor = AppColors.mutedForeground,
  }) {
    final badge = _badge(key);

    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: signed,
      ),
      style: mono(size: 14),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        errorText: _errors[key],
        helperText: note ?? badge,
        helperStyle: TextStyle(
          fontSize: 11.5,
          color: note != null ? noteColor : AppColors.gold,
        ),
        helperMaxLines: 4,
      ),
    );
  }

  Widget _timeField(
    String label,
    DateTime? value,
    String key, {
    required bool closed,
  }) => InkWell(
    onTap: () => _pickTime(closed: closed),
    borderRadius: BorderRadius.circular(kRadius - 2),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: '$label *',
        errorText: _errors[key],
        helperText: _badge(key),
        helperStyle: const TextStyle(fontSize: 11.5, color: AppColors.gold),
        suffixIcon: const Icon(Icons.event, size: 18),
      ),
      child: Text(
        value == null ? 'Pilih tanggal & jam' : dateTime(value),
        style: const TextStyle(fontSize: 14),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Caption(
          widget.onDiscard == null
              ? 'Isi manual, atau biarkan AI membaca screenshot lalu koreksi hasilnya.'
              : 'Satu tab satu trade. Semua tab disimpan sekaligus.',
        ),
        const SizedBox(height: 12),
        if (!_editing && widget.aiEnabled)
          OutlinedButton.icon(
            onPressed: widget.busy ? null : widget.onImport,
            icon: const Icon(
              Icons.auto_awesome,
              color: AppColors.gold,
              size: 18,
            ),
            label: const Text('Isi dari screenshot'),
          )
        else if (!_editing)
          const Caption(
            'Import AI nonaktif karena kunci Gemini belum diisi admin.',
          ),
        if (_aiFields.isNotEmpty) ...[
          const SizedBox(height: 12),
          Notice(
            icon: Icons.auto_awesome,
            child: Text(
              '${_aiFields.length} field terisi dari gambar. '
              '${_lowConfidence.isEmpty ? '' : 'AI ragu pada: ${_lowConfidence.join(', ')}. '}'
              'Periksa semua angka sebelum menyimpan.',
            ),
          ),
        ],
        const SizedBox(height: 14),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _symbol,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  labelText: 'Simbol *',
                  hintText: 'XAUUSD',
                  errorText: _errors['symbol'],
                  helperText: _badge('symbol'),
                  helperStyle: const TextStyle(color: AppColors.gold),
                ),
              ),
              if (widget.symbols.isNotEmpty) ...[
                const SizedBox(height: 8),
                SuggestChips(
                  options: widget.symbols,
                  onSelected: (symbol) => _symbol.text = symbol,
                ),
              ],
              gap,
              Segments(
                value: _direction,
                options: const [('buy', 'Buy'), ('sell', 'Sell')],
                colors: const {
                  'buy': AppColors.success,
                  'sell': AppColors.destructive,
                },
                onChanged: (value) => setState(() => _direction = value),
              ),
              gap,
              _number(_lot, 'Lot', 'lot', hint: '0.05'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _number(
                _entry,
                'Entry',
                'entry_price',
                hint: '2412.35',
                required: true,
              ),
              gap,
              FieldPair(
                _number(_sl, 'Stop loss', 'sl_price', hint: '2405.00'),
                _number(
                  _tp,
                  'Take profit',
                  'tp_price',
                  hint: '2430.00',
                  note: _tpSideWrong
                      ? 'TP harus di ${_direction == 'buy' ? 'atas' : 'bawah'} entry.'
                      : null,
                  noteColor: AppColors.destructive,
                ),
              ),
              if (_stopNote != null) ...[
                const SizedBox(height: 10),
                Notice(
                  color: AppColors.cyan,
                  icon: Icons.shield_outlined,
                  child: Text(_stopNote!),
                ),
              ],
              if (_plannedRr != null) ...[
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    text: 'Risk/reward rencana: ',
                    children: [
                      TextSpan(
                        text: rr(_plannedRr),
                        style: const TextStyle(color: AppColors.gold),
                      ),
                    ],
                  ),
                  style: mono(size: 12, color: AppColors.mutedForeground),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _timeField('Dibuka', _openedAt, 'opened_at', closed: false),
              gap,
              _timeField('Ditutup', _closedAt, 'closed_at', closed: true),
              gap,
              FieldPair(
                _number(_exit, 'Harga keluar', 'exit_price', hint: 'Opsional'),
                _number(
                  _pnl,
                  'Hasil (${widget.currency})',
                  'pnl',
                  hint: 'Untung/rugi',
                  required: true,
                  signed: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_inGroup) ...[
          const Notice(
            icon: Icons.layers_outlined,
            child: Text(
              'Trade ini bagian dari sebuah grup. Setup dan catatannya dipakai bersama seluruh anggota grup, '
              'jadi dikunci di sini. Ubah lewat detail trade di tab Trade, atau keluarkan dari grupnya dulu.',
            ),
          ),
          const SizedBox(height: 12),
        ],
        Panel(
          title: 'Setup / strategi',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SetupPicker(
                value: _setup,
                enabled: !_inGroup,
                onChanged: (value) => setState(() => _setup = value),
              ),
              if (_badge('setup') != null || _errors['setup'] != null) ...[
                const SizedBox(height: 6),
                Caption(
                  _errors['setup'] ?? _badge('setup')!,
                  color: _errors['setup'] != null
                      ? AppColors.destructive
                      : AppColors.gold,
                ),
              ],
              gap,
              TextField(
                controller: _notes,
                enabled: !_inGroup,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'Catatan',
                  // Contoh nyata di dalam kolom, arahan tetap di bawahnya —
                  // yang di dalam hilang begitu mulai mengetik.
                  hintText:
                      'Contoh: Entry di retest support H1 setelah break of structure. '
                      'Terlalu cepat, harusnya tunggu candle konfirmasi.',
                  hintMaxLines: 3,
                  helperText:
                      'Tulis alasan masuk, kondisi pasar saat itu, dan pelajaran setelah trade selesai.',
                  alignLabelWithHint: true,
                  errorText: _errors['notes'],
                ),
              ),
            ],
          ),
        ),
        if (_aiPreview != null) ...[
          const SizedBox(height: 12),
          Panel(
            title: 'Gambar sumber',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InteractiveViewer(
                    child: Image.memory(_aiPreview!, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 8),
                const Caption(
                  'Hanya untuk mencocokkan angka. Gambar tidak disimpan dan akan hilang setelah form ditutup.',
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        BusyButton(
          busy: widget.busy,
          onPressed: widget.onSave,
          label: widget.saveLabel,
          icon: Icons.check,
        ),
        if (widget.onDiscard != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: widget.busy ? null : widget.onDiscard,
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Buang tab ini'),
          ),
        ],
      ],
    );
  }
}
