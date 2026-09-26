import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  setUpAll(setUpFormatting);

  // Balasan AI diketik tiap frame layar — di HP 120 Hz tiap 8 ms — bukan
  // dengan timer 16 ms yang menahannya di 60 kali per detik.
  testWidgets('balasan AI diketik mengikuti frame layar', (tester) async {
    final reply = List.filled(100, 'Jaga risiko per trade.').join(' ');

    await pumpApp(
      tester,
      routes: {
        'GET accounts/1/analysis': (_) => {
          ...fixture('analysis'),
          'aiEnabled': true,
        },
        'POST accounts/1/analysis/chat': (_) => {'reply': reply},
      },
    );
    await tester.tap(find.text('Lainnya').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analisa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanya AI'));
    await tester.pumpAndSettle();

    Future<void> ask() async {
      await tester.enterText(find.byType(TextField), 'Apa kelemahan saya?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      // Jam uji tidak maju: balasannya masuk dan detak pertamanya di waktu 0.
      for (var i = 0; i < 5; i++) {
        await tester.pump(Duration.zero);
      }
      await tester.pump(const Duration(milliseconds: 8)); // satu frame 120 Hz
    }

    await ask();
    // 400 huruf per detik × 8 ms.
    expect(find.text('Jag', findRichText: true), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text(reply), findsOneWidget);

    // Keluar di tengah ketikan: detaknya ikut dibuang bersama layarnya.
    await ask();
    expect(find.text('Jag', findRichText: true), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Tanya AI'), findsOneWidget);
  });
}
