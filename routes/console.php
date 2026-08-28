<?php

use App\Console\Commands\BackupDatabase;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Minggu pukul 03.00 waktu APP_TIMEZONE. Dijalankan oleh servis `scheduler`
// di compose — tanpa kontainer itu jadwal ini tidak pernah menyala.
Schedule::command(BackupDatabase::class)->weeklyOn(0, '03:00');
