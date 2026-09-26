<?php

use App\Console\Commands\BackupDatabase;
use App\Models\User;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;
use Laravel\Sanctum\PersonalAccessToken;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Minggu pukul 03.00 waktu APP_TIMEZONE. Dijalankan oleh servis `scheduler`
// di compose — tanpa kontainer itu jadwal ini tidak pernah menyala.
Schedule::command(BackupDatabase::class)->weeklyOn(0, '03:00');

// Token yang lama tidak dipakai sudah ditolak di setiap permintaan
// (AppServiceProvider); di sini barisnya dibuang supaya tidak menumpuk.
Schedule::call(fn () => PersonalAccessToken::whereRaw(
    'coalesce(last_used_at, created_at) < ?',
    [now()->subDays(User::TOKEN_IDLE_DAYS)],
)->delete())->daily()->name('prune-idle-tokens');
