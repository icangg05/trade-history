import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trade_history/data/session.dart';
import 'package:trade_history/widgets/common.dart';

class _List extends StatefulWidget {
  const _List(this.count, {this.loadingMore = false});

  final int count;
  final bool loadingMore;

  @override
  State<_List> createState() => _ListState();
}

class _ListState extends State<_List> with FadeNextPage {
  @override
  Widget build(BuildContext context) {
    trackNextPage(widget.loadingMore, widget.count);

    return Column(
      children: [
        for (var i = 0; i < widget.count; i++)
          FadeIn(animate: isNextPage(i), child: Text('$i')),
      ],
    );
  }
}

void main() {
  testWidgets('dimuat ulang setelah simpan → kerangka; tarik-segarkan tidak', (
    tester,
  ) async {
    final data = FutureProvider<int>((ref) async {
      final revision = ref.watch(revisionProvider);
      await Future<void>.delayed(const Duration(seconds: 1));
      return revision;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    Future<void> arrive() async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (_, ref, _) => AsyncView(
              value: ref.watch(data),
              loading: const Text('kerangka'),
              skeletonOnReload: true,
              builder: (value) => Text('isi $value'),
            ),
          ),
        ),
      ),
    );
    await arrive();
    expect(find.text('isi 0'), findsOneWidget);

    container.read(revisionProvider.notifier).bump();
    await tester.pump();
    expect(find.text('kerangka'), findsOneWidget);

    await arrive();
    expect(find.text('isi 1'), findsOneWidget);
    expect(find.text('kerangka'), findsNothing);

    container.refresh(data);
    await tester.pump();
    expect(find.text('kerangka'), findsNothing);
    await arrive();
  });

  testWidgets('hanya halaman yang baru tiba yang memudar masuk', (
    tester,
  ) async {
    double opacity(int i) => tester
        .widget<Opacity>(
          find.ancestor(of: find.text('$i'), matching: find.byType(Opacity)),
        )
        .opacity;

    await tester.pumpWidget(const MaterialApp(home: _List(2)));
    expect(opacity(1), 1);

    await tester.pumpWidget(
      const MaterialApp(home: _List(2, loadingMore: true)),
    );
    await tester.pumpWidget(const MaterialApp(home: _List(4)));
    expect(opacity(1), 1);
    expect(opacity(2), 0);

    await tester.pump(const Duration(milliseconds: 400));
    expect(opacity(2), 1);

    // Entri yang dibangun sesudah bingkai kedatangan tampil biasa.
    await tester.pumpWidget(const MaterialApp(home: _List(5)));
    expect(opacity(4), 1);
  });
}
