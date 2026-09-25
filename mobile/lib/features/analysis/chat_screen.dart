import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/json.dart';
import '../../core/theme.dart';
import '../../data/session.dart';
import '../../models/journal.dart';
import '../../widgets/common.dart';
import '../../widgets/markdown_view.dart';
import 'analysis_screen.dart';

const _suggestions = [
  'Apa kelemahan terbesar cara trading saya?',
  'Jam dan hari mana yang paling sering merugikan?',
  'Apakah RR saya sudah masuk akal?',
  'Apa satu hal yang harus saya perbaiki minggu depan?',
];

/// Kecepatan ketik: cukup pelan untuk terbaca, tapi balasan panjang tetap
/// selesai dalam beberapa detik.
const _charsPerSecond = 400;
const _maxSeconds = 6;

/// Tanya jawab dengan AI soal akun ini. Percakapan tidak disimpan server;
/// riwayatnya diingat di ponsel ini, per akun — sama seperti localStorage di web.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.period});

  final String period;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();

  List<ChatMessage> _messages = [];
  int? _account;
  bool _busy = false;
  String? _error;

  /// Huruf balasan terakhir yang sudah tampil; null = tampil penuh.
  int? _shown;
  Timer? _typing;

  String get _key => 'ai-chat:$_account';

  @override
  void dispose() {
    _typing?.cancel();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _load(int account) {
    if (_account == account) return;

    _account = account;

    try {
      final raw = ref.read(prefsProvider).getString(_key);

      _messages = raw == null
          ? []
          : list(jsonDecode(raw))
                .map((item) => ChatMessage.fromJson(map(item)))
                .toList();
    } on FormatException {
      _messages = [];
    }
  }

  void _persist() => ref
      .read(prefsProvider)
      .setString(_key, jsonEncode(_messages.map((m) => m.toJson()).toList()));

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  /// Balasan dimunculkan sedikit demi sedikit mengikuti waktu nyata.
  void _typeOut(String text) {
    const frame = Duration(milliseconds: 16);
    final speed = math.max(_charsPerSecond, text.length / _maxSeconds);

    _typing?.cancel();
    _shown = 0;
    _typing = Timer.periodic(frame, (timer) {
      // `tick` ikut menghitung periode yang terlewat saat layar tersendat,
      // jadi lajunya tetap mengikuti waktu nyata.
      final elapsed = timer.tick * frame.inMilliseconds / 1000;
      final shown = math.min(text.length, (elapsed * speed).round());

      if (!mounted) return timer.cancel();

      setState(() => _shown = shown >= text.length ? null : shown);

      if (_shown == null) timer.cancel();
      if (_scroll.hasClients &&
          _scroll.position.maxScrollExtent - _scroll.offset < 120) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _draft.text).trim();

    if (text.isEmpty || _busy || _account == null) return;

    _typing?.cancel();

    // Sepuluh giliran terakhir sudah cukup menjaga konteks; sisanya hanya
    // menambah token tanpa menambah jawaban.
    final history = _messages.length > 10
        ? _messages.sublist(_messages.length - 10)
        : [..._messages];

    setState(() {
      _shown = null;
      _messages = [..._messages, ChatMessage(role: 'user', text: text)];
      _draft.clear();
      _busy = true;
      _error = null;
    });
    _persist();
    _scrollDown();

    try {
      final reply = await ref
          .read(journalProvider)
          .chat(_account!, widget.period, text, history);

      if (!mounted) return;

      setState(
        () => _messages = [
          ..._messages,
          ChatMessage(role: 'assistant', text: reply),
        ],
      );
      _persist();
      _typeOut(reply);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollDown();
    }
  }

  Future<void> _clear() async {
    if (!await confirm(
      context,
      title: 'Bersihkan percakapan?',
      message: 'Riwayat chat di ponsel ini dihapus.',
      action: 'Bersihkan',
    )) {
      return;
    }

    _typing?.cancel();
    setState(() {
      _messages = [];
      _shown = null;
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(currentAccountProvider).value;

    if (account != null) _load(account.id);

    final enabled = account == null
        ? null
        : ref
              .watch(analysisProvider((account.id, widget.period)))
              .value
              ?.aiEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tanya AI',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'Berdasarkan statistik akun ini.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            TextButton(
              onPressed: _busy ? null : _clear,
              child: const Text('Bersihkan'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: enabled == false
            ? const Center(
                child: EmptyState(
                  icon: Icons.key_off_outlined,
                  message: 'Kunci Gemini belum diisi. Minta admin mengisinya di halaman Admin.',
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        if (_messages.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  color: AppColors.gold,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Tanyakan apa saja soal cara kamu trading.',
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final item in _suggestions)
                                      ActionChip(
                                        label: Text(
                                          item,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: kDenseChip,
                                        onPressed: () => _send(item),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        for (var i = 0; i < _messages.length; i++) _bubble(i),
                        if (_busy) const _Thinking(),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Notice(
                        color: AppColors.destructive,
                        child: Text(_error!),
                      ),
                    ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _draft,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 2000,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              hintText: 'Tulis pertanyaan…',
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          onPressed: _busy ? null : () => _send(),
                          icon: const Icon(Icons.send_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _bubble(int index) {
    final message = _messages[index];
    final last = index == _messages.length - 1;
    final text = last && !message.mine && _shown != null
        ? message.text.substring(0, _shown)
        : message.text;

    // Pertanyaan sendiri berbentuk gelembung di kanan; balasan AI dirender
    // sebagai markdown selebar kolom.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: message.mine
          ? Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .8,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(message.text, style: const TextStyle(fontSize: 14)),
              ),
            )
          : MarkdownView(text, selectable: _shown == null || !last),
    );
  }
}

class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Row(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Opacity(
              opacity:
                  .3 +
                  .7 *
                      (math.sin((_controller.value - i * .15) * 2 * math.pi) +
                          1) /
                      2,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
