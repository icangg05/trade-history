<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Process;
use RuntimeException;

/**
 * Cadangan database ke storage/app/backups. Dipakai dua arah: penjadwal
 * mingguan (routes/console.php) dan tombol unduh di halaman admin.
 */
class BackupDatabase extends Command
{
    /** Hanya empat berkas terbaru yang disimpan; sisanya dibuang tiap kali jalan. */
    public const KEEP = 4;

    protected $signature = 'db:backup';

    protected $description = 'Simpan cadangan database dan buang yang lebih tua dari 4 terakhir';

    public function handle(): int
    {
        $this->info('Cadangan tersimpan: '.self::dump());

        return self::SUCCESS;
    }

    /**
     * Tulis dump baru, buang yang lama, kembalikan path berkasnya.
     *
     * @throws RuntimeException kalau koneksinya bukan MySQL atau mysqldump gagal
     */
    public static function dump(): string
    {
        $db = config('database.connections.'.config('database.default'));

        if ($db['driver'] !== 'mysql') {
            throw new RuntimeException('Backup hanya tersedia untuk MySQL.');
        }

        File::ensureDirectoryExists(self::dir());
        $path = self::dir().'/'.$db['database'].'-'.now()->format('Y-m-d-His').'.sql';

        // Kata sandi lewat environment, bukan argumen — argumen terbaca di daftar proses.
        $dump = Process::env(['MYSQL_PWD' => $db['password']])
            ->timeout(300)
            ->run([
                'mysqldump',
                '--host='.$db['host'],
                '--port='.$db['port'],
                '--user='.$db['username'],
                '--single-transaction',
                '--quick',
                // Tanpa --set-gtid-purged: klien di image ini mariadb-dump,
                // yang tidak mengenal opsi khusus MySQL itu.
                '--no-tablespaces',
                // MySQL memakai sertifikat bikinan sendiri dan hanya bisa dihubungi
                // dari jaringan compose, jadi verifikasi sertifikatnya dilewati.
                '--ssl-verify-server-cert=0',
                // Langsung ke berkas: dump tidak perlu singgah di memori PHP.
                '--result-file='.$path,
                $db['database'],
            ]);

        if ($dump->failed()) {
            File::delete($path);

            throw new RuntimeException('mysqldump gagal: '.$dump->errorOutput());
        }

        self::prune(self::dir());

        return $path;
    }

    public static function dir(): string
    {
        return storage_path('app/backups');
    }

    /** Cadangan yang tersimpan, terbaru dulu — dipakai daftar unduhan di halaman admin. */
    public static function files(): array
    {
        return collect(File::glob(self::dir().'/*.sql') ?: [])
            ->sortDesc()
            ->values()
            ->map(fn (string $path) => [
                'name' => basename($path),
                'size' => round(File::size($path) / 1024).' KB',
                'created_at' => Carbon::createFromTimestamp(File::lastModified($path))->toIso8601String(),
            ])
            ->all();
    }

    /** Sisakan KEEP berkas terbaru. Nama berpola Y-m-d-His: urutan abjad = urutan waktu. */
    public static function prune(string $dir): void
    {
        File::delete(collect(File::glob($dir.'/*.sql') ?: [])->sortDesc()->slice(self::KEEP)->all());
    }
}
