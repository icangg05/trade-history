<?php

namespace App\Services;

use App\Models\Account;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Berkas milik pengguna (saat ini: bukti deposit/withdrawal) disimpan di disk
 * `local` (storage/app/private) — tidak pernah bisa diakses lewat URL publik.
 *
 * Screenshot trade sengaja TIDAK lewat sini: gambar itu hanya dibaca AI lalu
 * dibuang, supaya penyimpanan tidak membengkak.
 */
class Uploads
{
    public const DISK = 'local';

    public static function store(UploadedFile $file, Account $account, string $folder): string
    {
        $path = $folder.'/'.$account->id.'/'.Str::ulid().'.'.$file->extension();

        Storage::disk(self::DISK)->put($path, $file->get());

        return $path;
    }

    public static function delete(?string $path): void
    {
        if (filled($path)) {
            Storage::disk(self::DISK)->delete($path);
        }
    }
}
