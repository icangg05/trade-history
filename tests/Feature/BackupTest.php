<?php

namespace Tests\Feature;

use App\Console\Commands\BackupDatabase;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use Tests\TestCase;

class BackupTest extends TestCase
{
    use RefreshDatabase;

    public function test_hanya_empat_cadangan_terbaru_yang_disimpan(): void
    {
        // Direktori sementara: jangan sentuh cadangan sungguhan di storage/app/backups.
        $dir = storage_path('framework/testing/backups');
        File::deleteDirectory($dir);
        File::ensureDirectoryExists($dir);

        // Enam berkas lama; nama berpola tanggal seperti yang ditulis command.
        foreach (range(1, 6) as $i) {
            File::put($dir.'/trade_history-2026-01-0'.$i.'-030000.sql', 'x');
        }

        // Pemangkasan diuji lepas dari mysqldump — CI tidak punya MySQL.
        BackupDatabase::prune($dir);

        $sisa = array_map('basename', File::glob($dir.'/*.sql'));
        sort($sisa);

        $this->assertSame([
            'trade_history-2026-01-03-030000.sql',
            'trade_history-2026-01-04-030000.sql',
            'trade_history-2026-01-05-030000.sql',
            'trade_history-2026-01-06-030000.sql',
        ], $sisa);
    }

    /**
     * Nama berkas datang dari URL — pastikan hanya pola dump yang lolos,
     * bukan jalan menuju berkas lain seperti .env.
     */
    public function test_nama_berkas_di_luar_pola_cadangan_ditolak(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);

        $this->actingAs($admin)->get('/admin/backup/..%2F..%2F..%2F.env')->assertNotFound();
        $this->actingAs($admin)->get('/admin/backup/tidak-ada.sql')->assertNotFound();
    }
}
