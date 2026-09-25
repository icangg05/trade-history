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
     */
    public static function image(UploadedFile $file, string $folder, int $maxSide, int $quality = 85): string
    {
        $source = @imagecreatefromstring($file->get());

        if ($source === false) {
            throw new RuntimeException('Gambar tidak bisa dibuka GD.');
        }

        $source = self::upright($source, $file->getRealPath());

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
        $jpeg = ob_get_clean();

        $path = $folder.'/'.Str::ulid().'.jpg';

        Storage::disk(self::DISK)->put($path, $jpeg);

        return $path;
    }

    public static function delete(?string $path): void
    {
        if (filled($path)) {
            Storage::disk(self::DISK)->delete($path);
        }
    }

    /**
     * Foto kamera sering disimpan miring dengan tanda EXIF "putar sekian
     * derajat". Tanda itu hilang saat disimpan ulang, jadi putarannya
     * diterapkan ke pikselnya dulu. Hanya JPEG yang membawa EXIF; format lain
     * lolos apa adanya.
     */
    private static function upright(GdImage $image, string $path): GdImage
    {
        $orientation = (@exif_read_data($path) ?: [])['Orientation'] ?? 1;

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
