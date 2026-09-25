import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trade_history/core/theme.dart';
import 'package:trade_history/widgets/avatar_cropper.dart';

void main() {
  testWidgets('foto lebar dipotong jadi PNG persegi 512 px', (tester) async {
    final photo = (await tester.runAsync(() {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 300, 150),
        Paint()..color = const Color(0xFF3366CC),
      );
      return recorder.endRecording().toImage(300, 150);
    }))!;

    Uint8List? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.push(
              context,
              MaterialPageRoute<Uint8List>(
                builder: (_) => AvatarCropper(image: photo),
              ),
            ),
            child: const Text('buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    // Tangkapan layar dan PNG dikerjakan di luar jam palsu test.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pumpAndSettle();

    expect(result, isNotNull);

    final cropped = (await tester.runAsync(
      () => decodeImageFromList(result!),
    ))!;
    expect([cropped.width, cropped.height], [512, 512]);
  });
}
