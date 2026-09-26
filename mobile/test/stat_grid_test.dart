import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trade_history/widgets/common.dart';

void main() {
  testWidgets('kartu sebaris sama tinggi walau keterangannya dua baris', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: StatGrid(
              children: [
                StatCard(label: 'Winrate', value: '52,6%', hint: '1W / 1L'),
                StatCard(
                  label: 'Profit factor',
                  value: '1,32',
                  hint: 'Rata-rata +39,36 USC per trade yang panjang sekali',
                ),
                StatCard(label: 'Ganjil', value: '1'),
              ],
            ),
          ),
        ),
      ),
    );

    final cards = find.byType(StatCard);
    final first = tester.getSize(cards.at(0));
    final second = tester.getSize(cards.at(1));

    expect(first.height, second.height);
    // Kartu ketiga sendirian di barisnya, tapi tetap selebar satu kolom.
    expect(tester.getSize(cards.at(2)).width, first.width);
  });
}
