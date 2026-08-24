<?php

use App\Http\Controllers\AccountController;
use App\Http\Controllers\AdminController;
use App\Http\Controllers\AnalysisController;
use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\Auth\RegisterController;
use App\Http\Controllers\CalendarController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\RuleController;
use App\Http\Controllers\TradeController;
use App\Http\Controllers\TradeImportController;
use App\Http\Controllers\TransactionController;
use Illuminate\Support\Facades\Route;

Route::middleware('guest')->group(function () {
    Route::get('/login', [LoginController::class, 'create'])->name('login');
    Route::post('/login', [LoginController::class, 'store'])->middleware('throttle:10,1');

    Route::get('/register', [RegisterController::class, 'create'])->name('register');
    Route::post('/register', [RegisterController::class, 'store'])->middleware('throttle:5,1');
});

Route::middleware('auth')->group(function () {
    Route::post('/logout', [LoginController::class, 'destroy'])->name('logout');

    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::put('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');

    // Admin: kelola pengguna dan kunci Gemini. Tidak butuh akun trading aktif.
    Route::middleware('admin')->prefix('admin')->name('admin.')->group(function () {
        Route::get('/', [AdminController::class, 'index'])->name('index');
        Route::post('/users', [AdminController::class, 'storeUser'])->name('users.store');
        Route::put('/users/{user}', [AdminController::class, 'updateUser'])->name('users.update');
        Route::delete('/users/{user}', [AdminController::class, 'destroyUser'])->name('users.destroy');
        Route::put('/gemini', [AdminController::class, 'updateGemini'])->name('gemini.update');
        Route::delete('/gemini', [AdminController::class, 'forgetGeminiKey'])->name('gemini.forget');
        Route::get('/backup', [AdminController::class, 'backup'])->middleware('throttle:5,1')->name('backup');
    });

    // Semua di bawah ini milik trader; admin dilempar balik ke halamannya.
    Route::middleware('trader')->group(function () {

        // Akun bisa diakses tanpa akun aktif — di sinilah akun pertama dibuat.
        Route::get('/accounts', [AccountController::class, 'index'])->name('accounts.index');
        Route::post('/accounts', [AccountController::class, 'store'])->name('accounts.store');
        Route::put('/accounts/{account}', [AccountController::class, 'update'])->name('accounts.update');
        Route::delete('/accounts/{account}', [AccountController::class, 'destroy'])->name('accounts.destroy');
        Route::post('/accounts/{account}/switch', [AccountController::class, 'switch'])->name('accounts.switch');

        // Semua di bawah ini butuh akun aktif.
        Route::middleware('account')->group(function () {
            Route::get('/', DashboardController::class)->name('dashboard');
            Route::get('/calendar', CalendarController::class)->name('calendar');

            Route::get('/trades', [TradeController::class, 'index'])->name('trades.index');
            Route::get('/trades/create', [TradeController::class, 'create'])->name('trades.create');
            Route::post('/trades', [TradeController::class, 'store'])->name('trades.store');
            Route::post('/trades/extract', TradeImportController::class)
                ->middleware('throttle:20,1')
                ->name('trades.extract');
            Route::get('/trades/{trade}/edit', [TradeController::class, 'edit'])->name('trades.edit');
            Route::put('/trades/{trade}', [TradeController::class, 'update'])->name('trades.update');
            Route::delete('/trades/{trade}', [TradeController::class, 'destroy'])->name('trades.destroy');

            Route::get('/transactions', [TransactionController::class, 'index'])->name('transactions.index');
            Route::post('/transactions', [TransactionController::class, 'store'])->name('transactions.store');
            Route::get('/transactions/{transaction}/proof', [TransactionController::class, 'proof'])->name('transactions.proof');
            Route::delete('/transactions/{transaction}', [TransactionController::class, 'destroy'])->name('transactions.destroy');

            Route::get('/rules', [RuleController::class, 'edit'])->name('rules.edit');
            Route::put('/rules', [RuleController::class, 'update'])->name('rules.update');

            Route::get('/analysis', [AnalysisController::class, 'index'])->name('analysis.index');
            Route::post('/analysis', [AnalysisController::class, 'generate'])
                ->middleware('throttle:10,1')
                ->name('analysis.generate');
        });
    });
});
