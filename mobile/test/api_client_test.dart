import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trade_history/core/api_client.dart';

/// Adapter yang benar-benar menghabiskan badan permintaan, seperti soket —
/// kemajuan kirim Dio baru terhitung saat potongannya diambil.
class _Drain implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();

    return ResponseBody.fromString(
      '{"message":"ok"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('gambar terunggah bertahap, bukan satu lompatan ke 100%', () async {
    final client = ApiClient(server: 'https://contoh.test', adapter: _Drain());
    final steps = <double>[];

    await client.post(
      'transactions',
      FormData.fromMap({'proof': chunkedFile(Uint8List(300 * 1024), 'b.jpg')}),
      (sent, total) => steps.add(sent / total),
    );

    // 300 KB per 64 KB = 5 potongan berkas, plus kepala & penutup multipart.
    expect(steps.length, greaterThanOrEqualTo(5));
    expect(steps.where((step) => step > .1 && step < .9), isNotEmpty);
    expect(steps.last, 1);
  });
}
