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
Route::prefix('v1')->group(function () {
    Route::get('/auth/options', [AuthController::class, 'options']);
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:10,1');
    Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:5,1');

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);

        Route::get('/profile', [ProfileController::class, 'edit']);
        Route::put('/profile', [ProfileController::class, 'update']);
        Route::delete('/profile', [ProfileController::class, 'destroy']);
        Route::get('/profile/avatar', [ProfileController::class, 'avatar']);
        Route::post('/profile/avatar', [ProfileController::class, 'updateAvatar']);
        Route::delete('/profile/avatar', [ProfileController::class, 'destroyAvatar']);

        Route::middleware('trader')->group(function () {
            Route::get('/accounts', [AccountController::class, 'index']);
            Route::post('/accounts', [AccountController::class, 'store']);
            Route::put('/accounts/{account}', [AccountController::class, 'update']);
            Route::delete('/accounts/{account}', [AccountController::class, 'destroy']);

            // Laporan pajak menjumlahkan semua akun, termasuk yang diarsipkan —
            // jadi tidak bergantung pada akun yang sedang dibuka.
            Route::get('/reports', [ReportController::class, 'index']);
            Route::post('/reports/pdf', [ReportController::class, 'pdf']);

            Route::prefix('accounts/{account}')->middleware('api.account')->group(function () {
                Route::get('/dashboard', DashboardController::class);
                Route::get('/calendar', CalendarController::class);

                Route::get('/trades', [TradeController::class, 'index']);
                Route::post('/trades', [TradeController::class, 'store']);
                // Form trade baru: cukup tahu apakah import AI tersedia.
                Route::get('/trades/create', [TradeController::class, 'create']);
                Route::post('/trades/extract', TradeImportController::class)->middleware('throttle:20,1');
                Route::post('/trades/group', [TradeController::class, 'group']);
                Route::put('/trades/group/{group}', [TradeController::class, 'updateGroup']);
                Route::delete('/trades/{trade}/group', [TradeController::class, 'ungroup']);
                Route::get('/trades/{trade}', [TradeController::class, 'edit']);
                Route::put('/trades/{trade}', [TradeController::class, 'update']);
                Route::delete('/trades/{trade}', [TradeController::class, 'destroy']);

                Route::get('/transactions', [TransactionController::class, 'index']);
                Route::post('/transactions', [TransactionController::class, 'store']);
                // POST, sama seperti di web: bukti transfer ikut sebagai multipart.
                Route::post('/transactions/{transaction}', [TransactionController::class, 'update']);
                Route::get('/transactions/{transaction}/proof', [TransactionController::class, 'proof']);
                Route::delete('/transactions/{transaction}', [TransactionController::class, 'destroy']);

                Route::get('/rules', [RuleController::class, 'edit']);
                Route::put('/rules', [RuleController::class, 'update']);

                Route::get('/analysis', [AnalysisController::class, 'index']);
                Route::post('/analysis', [AnalysisController::class, 'generate'])->middleware('throttle:10,1');
                Route::post('/analysis/chat', [AnalysisController::class, 'chat'])->middleware('throttle:30,1');
            });
        });
    });
});
