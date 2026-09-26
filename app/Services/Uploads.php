<?php

namespace App\Services;

use Closure;
use GdImage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Berkas milik pengguna (bukti deposit/withdrawal, foto profil) disimpan di
 * disk `local` (storage/app/private) — tidak pernah bisa diakses lewat URL publik.
 *
 * Semua gambar dinormalkan di sini, apa pun asalnya (web, aplikasi mobile,
 * atau panggilan API langsung): diputar sesuai EXIF, diperkecil, lalu disimpan
 * ulang sebagai JPEG. Aplikasi mobile ikut mengecilkan sebelum mengirim, tapi
 * itu hanya penghemat kuota — yang menjamin ukuran dan isi berkas adalah server.
 * Menyimpan ulang juga membuang metadata (lokasi GPS) dan apa pun yang
 * diselipkan di dalam berkas gambar.
 *
 * Screenshot trade sengaja TIDAK lewat sini: gambar itu hanya dibaca AI lalu
 * dibuang, supaya penyimpanan tidak membengkak.
 */
class Uploads
{
    public const DISK = 'local';

    /**
     * Batas resolusi yang mau dibuka. GD memegang gambar utuh di memori
     * (±4 byte per piksel): 50 MP ≈ 200 MB, masih muat di memory_limit 512 MB.
     */
    private const MAX_PIXELS = 50_000_000;

    /**
     * Aturan validasi pendamping image(): dimensinya dibaca dari header
     * berkas, sebelum GD membongkarnya — gambar raksasa ditolak tanpa sempat
     * menghabiskan memori.
     */
    public static function readable(): Closure
    {
        return function (string $attribute, mixed $value, Closure $fail) {
            $size = $value instanceof UploadedFile ? @getimagesize($value->getRealPath()) : false;

            if ($size === false) {
                $fail('Berkas harus berupa gambar.');
            } elseif ($size[0] * $size[1] > self::MAX_PIXELS) {
                $fail('Resolusi gambar terlalu besar (maksimal 50 megapiksel).');
            }
        };
    }

    /**
     * Simpan gambar yang sudah lolos `readable()`. Sisi terpanjangnya dibatasi
     * $maxSide; gambar yang lebih kecil tidak diperbesar.
     *
     * Hasilnya tidak pernah lebih besar dari yang perlu: gambar yang sudah
     * kecil dan tegak bisa membengkak kalau dikodekan ulang (JPEG yang sudah
     * dikompres pengirimnya, screenshot PNG berwarna datar). Untuk gambar
     * seperti itu, aslinya — dengan metadatanya dibuang — ikut dibandingkan,
     * dan yang lebih kecil yang disimpan.
     */
    public static function image(UploadedFile $file, string $folder, int $maxSide, int $quality = 85): string
    {
        $original = $file->get();
        $source = @imagecreatefromstring($original);

        if ($source === false) {
            throw new RuntimeException('Gambar tidak bisa dibuka GD.');
        }

        $orientation = (int) ((@exif_read_data($file->getRealPath()) ?: [])['Orientation'] ?? 1);
        $source = self::upright($source, $orientation);

        $width = imagesx($source);
        $height = imagesy($source);
        $scale = min(1, $maxSide / max($width, $height));
        $w = max(1, (int) round($width * $scale));
        $h = max(1, (int) round($height * $scale));

        // Kanvas putih: bagian transparan PNG jadi putih, bukan hitam, begitu
        // disimpan sebagai JPEG yang tidak punya transparansi.
        $canvas = imagecreatetruecolor($w, $h);
        imagefill($canvas, 0, 0, imagecolorallocate($canvas, 255, 255, 255));
        imagecopyresampled($canvas, $source, 0, 0, 0, 0, $w, $h, $width, $height);

        ob_start();
        imagejpeg($canvas, null, $quality);
        [$bytes, $extension] = [ob_get_clean(), 'jpg'];

        // Aslinya hanya boleh dipakai kalau memang tidak perlu diubah: tidak
        // diperkecil, dan tidak bergantung pada tanda putar EXIF (tanda itu
        // ikut terbuang bersama metadatanya).
        if ($scale >= 1 && $orientation === 1) {
            foreach ([[self::strippedJpeg($original), 'jpg'], [self::strippedPng($original), 'png']] as [$clean, $type]) {
                if ($clean !== null && strlen($clean) < strlen($bytes)) {
                    [$bytes, $extension] = [$clean, $type];
                }
            }
        }

        $path = $folder.'/'.Str::ulid().'.'.$extension;

        Storage::disk(self::DISK)->put($path, $bytes);

        return $path;
    }

    /**
     * JPEG asli tanpa metadata: EXIF/XMP (termasuk lokasi GPS), IPTC, dan
     * komentar dibuang; profil warna ICC dipertahankan. Data gambarnya disalin
     * utuh, jadi kualitasnya persis sama. Apa pun yang menempel setelah
     * penanda akhir ikut terbuang. Null kalau bukan JPEG atau strukturnya aneh.
     */
    private static function strippedJpeg(string $data): ?string
    {
        if (! str_starts_with($data, "\xFF\xD8")) {
            return null;
        }

        $out = "\xFF\xD8";
        $at = 2;

        while ($at + 4 <= strlen($data) && $data[$at] === "\xFF") {
            $marker = ord($data[$at + 1]);

            if ($marker === 0xFF) {
                $at++; // byte pengisi

                continue;
            }

            // SOS: sisanya data gambar, sampai penanda akhir.
            if ($marker === 0xDA) {
                $end = strrpos($data, "\xFF\xD9");

                return $end === false || $end < $at ? null : $out.substr($data, $at, $end + 2 - $at);
            }

            $size = unpack('n', $data, $at + 2)[1];
            $icc = $marker === 0xE2 && substr($data, $at + 4, 11) === 'ICC_PROFILE';

            if (! (($marker >= 0xE1 && $marker <= 0xEF && ! $icc) || $marker === 0xFE)) {
                $out .= substr($data, $at, 2 + $size);
            }

            $at += 2 + $size;
        }

        return null;
    }

    /**
     * PNG asli tanpa chunk teks, waktu, dan EXIF. Chunk gambar, warna, dan
     * transparansi tetap. Null kalau bukan PNG atau tidak ada penanda akhirnya.
     */
    private static function strippedPng(string $data): ?string
    {
        if (! str_starts_with($data, "\x89PNG\r\n\x1A\n")) {
            return null;
        }

        $out = substr($data, 0, 8);
        $at = 8;

        while ($at + 12 <= strlen($data)) {
            $size = unpack('N', $data, $at)[1];
            $type = substr($data, $at + 4, 4);

            if (! in_array($type, ['tEXt', 'zTXt', 'iTXt', 'eXIf', 'tIME'], true)) {
                $out .= substr($data, $at, 12 + $size);
            }

            if ($type === 'IEND') {
                return $out;
            }

            $at += 12 + $size;
        }

        return null;
    }

    public static function delete(?string $path): void
    {
        if (filled($path)) {
            Storage::disk(self::DISK)->delete($path);
        }
    }

    /** Buang satu folder beserta seluruh isinya; aman kalau foldernya belum ada. */
    public static function deleteFolder(string $folder): void
    {
        Storage::disk(self::DISK)->deleteDirectory($folder);
    }

    /**
     * Foto kamera sering disimpan miring dengan tanda EXIF "putar sekian
     * derajat". Tanda itu hilang saat disimpan ulang, jadi putarannya
     * diterapkan ke pikselnya dulu. Hanya JPEG yang membawa EXIF; format lain
     * lolos apa adanya.
     */
    private static function upright(GdImage $image, int $orientation): GdImage
    {
        match ($orientation) {
            2, 7 => imageflip($image, IMG_FLIP_HORIZONTAL),
            4, 5 => imageflip($image, IMG_FLIP_VERTICAL),
            default => null,
        };

        // imagerotate berputar berlawanan arah jarum jam.
        return match ($orientation) {
            3 => imagerotate($image, 180, 0),
            5, 6, 7 => imagerotate($image, -90, 0),
            8 => imagerotate($image, 90, 0),
            default => $image,
        } ?: $image;
    }
}
