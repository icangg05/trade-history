import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../core/theme.dart';

/// Markdown untuk catatan aturan dan jawaban AI, bergaya `.rte-content` web.
///
/// Bisa dipilih lewat satu `SelectionArea` untuk seluruh teks, bukan
/// `selectable: true` milik paket markdown: yang itu menjadikan setiap
/// paragraf `SelectableText` (lengkap dengan kursor dan pengenal gestur
/// sendiri), dan analisa AI yang panjang jadi berat dibangun saat di-scroll.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.source, {super.key, this.selectable = true});

  final String source;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(
      fontSize: 14,
      height: 1.55,
      color: AppColors.foreground,
    );

    final markdown = MarkdownBody(
      data: source,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: body,
        listBullet: body,
        strong: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.foreground,
        ),
        em: const TextStyle(fontStyle: FontStyle.italic),
        h1: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        h2: const TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: AppColors.gold,
        ),
        h3: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        code: mono(
          size: 12.5,
          color: AppColors.accentForeground,
        ).copyWith(backgroundColor: AppColors.muted),
        codeblockDecoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.gold, width: 3)),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        a: const TextStyle(
          color: AppColors.gold,
          decoration: TextDecoration.underline,
        ),
        tableBorder: TableBorder.all(color: AppColors.border),
        tableHead: const TextStyle(fontWeight: FontWeight.w600),
        tableBody: const TextStyle(fontSize: 13),
        blockSpacing: 10,
      ),
    );

    return selectable ? SelectionArea(child: markdown) : markdown;
  }
}
