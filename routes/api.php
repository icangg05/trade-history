<?php

use App\Http\Controllers\AccountController;
use App\Http\Controllers\AnalysisController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\CalendarController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\RuleController;
use App\Http\Controllers\TradeController;
use App\Http\Controllers\TradeImportController;
use App\Http\Controllers\TransactionController;
use Illuminate\Support\Facades\Route;

/*
 * API untuk aplikasi mobile (folder `mobile/`, Flutter).
 *
 * Controllernya sama dengan halaman web — mereka menjawab JSON begitu alamatnya
 * di bawah /api (lihat Controller::page()). Bedanya cuma dua: masuk lewat token
 * Sanctum, bukan sesi, dan akun yang dibuka ikut di alamat
 * (`accounts/{account}/…`), bukan disimpan di sesi.
 */
/*
 * Throttle angka selalu diberi awalan (`throttle:10,1,login`). Tanpa awalan,
 * Laravel memakai satu hitungan per pengguna untuk semua rute — sepuluh pesan
 * chat semenit ikut menghabiskan jatah "buat analisa".
 */
Route::prefix('v1')->middleware('throttle:api')->group(function () {
    Route::get('/auth/options', [AuthController::class, 'options']);
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:10,1,login');
    Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:5,1,register');
    Route::post('/auth/password/forgot', [AuthController::class, 'forgotPassword'])->middleware('throttle:5,1,forgot');
    // Verifikasi dan ganti sandi berbagi jatah `reset`: keduanya menebak kode.
    Route::post('/auth/password/verify', [AuthController::class, 'verifyResetCode'])->middleware('throttle:10,1,reset');
    Route::post('/auth/password/reset', [AuthController::class, 'resetPassword'])->middleware('throttle:10,1,reset');

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::get('/devices', [AuthController::class, 'devices']);
        Route::delete('/devices/{device}', [AuthController::class, 'destroyDevice'])->whereNumber('device');

        Route::get('/profile', [ProfileController::class, 'edit']);
        Route::put('/profile', [ProfileController::class, 'update']);
        Route::delete('/profile', [ProfileController::class, 'destroy']);
        Route::get('/profile/avatar', [ProfileController::class, 'avatar']);
        Route::post('/profile/avatar', [ProfileController::class, 'updateAvatar'])->middleware('throttle:20,1,upload');
        Route::delete('/profile/avatar', [ProfileController::class, 'destroyAvatar']);

        Route::middleware('trader')->group(function () {
            Route::get('/accounts', [AccountController::class, 'index']);
            Route::post('/accounts', [AccountController::class, 'store']);
            Route::put('/accounts/{account}', [AccountController::class, 'update']);
            Route::delete('/accounts/{account}', [AccountController::class, 'destroy']);

            // Laporan pajak menjumlahkan semua akun, termasuk yang diarsipkan —
            // jadi tidak bergantung pada akun yang sedang dibuka.
            Route::get('/reports', [ReportController::class, 'index']);
            Route::post('/reports/pdf', [ReportController::class, 'pdf'])->middleware('throttle:5,1,pdf');

            Route::prefix('accounts/{account}')->middleware('api.account')->group(function () {
                Route::get('/dashboard', DashboardController::class);
                Route::get('/calendar', CalendarController::class);

                Route::get('/trades', [TradeController::class, 'index']);
                Route::post('/trades', [TradeController::class, 'store']);
                // Form trade baru: cukup tahu apakah import AI tersedia.
                Route::get('/trades/create', [TradeController::class, 'create']);
                Route::post('/trades/extract', TradeImportController::class)->middleware('throttle:20,1,extract');
                Route::post('/trades/group', [TradeController::class, 'group']);
                Route::put('/trades/group/{group}', [TradeController::class, 'updateGroup']);
                Route::delete('/trades/{trade}/group', [TradeController::class, 'ungroup']);
                Route::get('/trades/{trade}', [TradeController::class, 'edit']);
                Route::put('/trades/{trade}', [TradeController::class, 'update']);
                Route::delete('/trades/{trade}', [TradeController::class, 'destroy']);

                Route::get('/transactions', [TransactionController::class, 'index']);
                // Gambar bukti diolah GD di memori (sampai 50 MP), jadi dibatasi
                // sendiri — berbagi jatah `upload` dengan foto profil.
                Route::post('/transactions', [TransactionController::class, 'store'])->middleware('throttle:20,1,upload');
                // POST, sama seperti di web: bukti transfer ikut sebagai multipart.
                Route::post('/transactions/{transaction}', [TransactionController::class, 'update'])->middleware('throttle:20,1,upload');
                Route::get('/transactions/{transaction}/proof', [TransactionController::class, 'proof']);
                Route::delete('/transactions/{transaction}', [TransactionController::class, 'destroy']);

                Route::get('/rules', [RuleController::class, 'edit']);
                Route::put('/rules', [RuleController::class, 'update']);

                Route::get('/analysis', [AnalysisController::class, 'index']);
                Route::post('/analysis', [AnalysisController::class, 'generate'])->middleware('throttle:10,1,analysis');
                Route::post('/analysis/chat', [AnalysisController::class, 'chat'])->middleware('throttle:30,1,chat');
            });
        });
    });
});
