import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'json.dart';

/// Galat dari server, sudah dalam kalimat yang bisa langsung ditampilkan.
/// `errors` berisi pesan pertama per kolom dari ValidationException Laravel.
class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.errors = const {}});

  final String message;
  final int? status;
  final Map<String, String> errors;

  String? operator [](String field) => errors[field];

  @override
  String toString() => message;
}

/// Alamat server seperti yang diketik pengguna → bentuk bakunya: skema wajib
/// (https bila tidak ditulis), tanpa garis miring di ujung.
String normalizeServer(String raw) {
  var value = raw.trim();

  if (value.isEmpty) return value;
  if (!value.contains('://')) value = 'https://$value';

  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }

  return value;
}

/// Pembungkus Dio untuk `/api/v1`. Semua jawaban dibaca sebagai JSON; token
/// Sanctum dikirim di header Authorization.
class ApiClient {
  ApiClient({
    required String server,
    this.token,
    this.onUnauthorized,
    HttpClientAdapter? adapter,
  }) : root = '${normalizeServer(server)}/api/v1/',
       dio = Dio(
         BaseOptions(
           baseUrl: '${normalizeServer(server)}/api/v1/',
           connectTimeout: const Duration(seconds: 15),
           // Analisa AI penuh bisa makan 20–60 detik.
           receiveTimeout: const Duration(seconds: 120),
           headers: {
             'Accept': 'application/json',
             if (token != null) 'Authorization': 'Bearer $token',
           },
         ),
       ) {
    if (adapter != null) dio.httpClientAdapter = adapter;
  }

  final String root;
  final String? token;
  final Dio dio;

  /// Dipanggil saat server menjawab 401: tokennya dicabut atau kedaluwarsa.
  final void Function()? onUnauthorized;

  /// Header untuk `Image.network` — gambar bukti transfer juga butuh token.
  Map<String, String> get imageHeaders => {
    if (token != null) 'Authorization': 'Bearer $token',
  };

  String url(String path) => '$root$path';

  Future<Json> get(String path, {Map<String, dynamic>? query}) =>
      _json(() => dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<Json> post(String path, [Object? data]) =>
      _json(() => dio.post<dynamic>(path, data: data));

  Future<Json> put(String path, [Object? data]) =>
      _json(() => dio.put<dynamic>(path, data: data));

  Future<Json> delete(String path, [Object? data]) =>
      _json(() => dio.delete<dynamic>(path, data: data));

  /// Unduhan biner (PDF laporan). Galatnya tetap JSON, jadi dibaca ulang.
  Future<Uint8List> download(String path, {Object? data}) => _bytes(
    () => dio.post<List<int>>(
      path,
      data: data,
      options: Options(responseType: ResponseType.bytes),
    ),
  );

  /// Berkas biner lewat GET — bukti transfer yang disimpan ke galeri.
  Future<Uint8List> bytes(String path) => _bytes(
    () => dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    ),
  );

  Future<Uint8List> _bytes(Future<Response<List<int>>> Function() send) async {
    try {
      return Uint8List.fromList((await send()).data ?? const []);
    } on DioException catch (error) {
      throw _wrap(error);
    }
  }

  Future<Json> _json(Future<Response<dynamic>> Function() send) async {
    try {
      return map((await send()).data);
    } on DioException catch (error) {
      throw _wrap(error);
    }
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    query?.removeWhere((_, value) => value == null || value == '');

    return query;
  }

  ApiException _wrap(DioException error) {
    final response = error.response;

    if (response == null) {
      return ApiException(switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'Server terlalu lama menjawab. Coba lagi sebentar lagi.',
        DioExceptionType.badCertificate =>
          'Sertifikat HTTPS server tidak valid.',
        DioExceptionType.cancel => 'Permintaan dibatalkan.',
        _ => 'Tidak bisa terhubung ke server. Periksa alamat server dan koneksi internet.',
      });
    }

    final status = response.statusCode ?? 0;
    final body = _body(response.data);
    final errors = {
      for (final entry in map(body['errors']).entries)
        if (list(entry.value).isNotEmpty)
          entry.key: validationMessage('${list(entry.value).first}'),
    };

    if (status == 401) onUnauthorized?.call();

    // Pesan dari controller kita sendiri berbahasa Indonesia dan boleh tampil
    // apa adanya. Pesan bawaan framework (404, 401, 429, 500) tidak.
    final own =
        toStringOrNull(body['error']) ?? toStringOrNull(body['message']);
    final message = switch (status) {
      401 => 'Sesi berakhir. Silakan masuk lagi.',
      404 => 'Data tidak ditemukan — mungkin sudah dihapus.',
      429 => 'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.',
      >= 500 && != 502 && != 503 =>
        'Server sedang bermasalah. Coba lagi nanti.',
      422 when errors.isNotEmpty => errors.values.first,
      _ => own ?? 'Permintaan gagal ($status).',
    };

    return ApiException(message, status: status, errors: errors);
  }

  static Json _body(Object? data) {
    if (data is Map) return map(data);

    if (data is List<int>) {
      try {
        return map(jsonDecode(utf8.decode(data)));
      } on FormatException {
        return {};
      }
    }

    return {};
  }
}

/// Server membawa `lang/id/validation.php`, jadi pesannya sudah berupa kalimat
/// dan dibiarkan apa adanya. Server lama yang belum punya berkas itu mengirim
/// kuncinya mentah (`validation.required`); kunci itu diterjemahkan di sini
/// supaya aplikasi tetap terbaca selama servernya belum diperbarui.
String validationMessage(String message) {
  if (!message.startsWith('validation.')) return message;

  final rule = message.substring('validation.'.length).split('.').first;

  return switch (rule) {
    'required' || 'required_if' || 'required_with' => 'Wajib diisi.',
    'numeric' || 'integer' || 'decimal' => 'Harus berupa angka.',
    'gt' || 'min' when message.endsWith('.string') => 'Terlalu pendek.',
    'gt' || 'min' => 'Nilainya terlalu kecil.',
    'max' when message.endsWith('.file') => 'Berkasnya terlalu besar.',
    'max' when message.endsWith('.string') => 'Terlalu panjang.',
    'max' || 'between' => 'Nilainya di luar batas.',
    'email' => 'Alamat email tidak valid.',
    'unique' => 'Sudah dipakai.',
    'confirmed' => 'Konfirmasinya tidak cocok.',
    'current_password' => 'Kata sandi sekarang salah.',
    'date' => 'Tanggal tidak valid.',
    'after_or_equal' || 'after' => 'Harus sama atau sesudah waktu buka.',
    'before_or_equal' || 'before' => 'Tanggalnya terlalu jauh ke depan.',
    'image' || 'mimes' || 'uploaded' => 'Berkas harus berupa gambar.',
    'in' => 'Pilihan tidak valid.',
    _ => 'Isian tidak valid.',
  };
}
