<?php

use App\Http\Controllers\AdminController;
use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\TransactionController;
use Illuminate\Support\Facades\Route;

/*
 * Versi web hanya untuk admin. Trader mencatat lewat aplikasi mobile (API di
 * routes/api.php, dengan controller yang sama).
 */
Route::middleware('guest')->group(function () {
    Route::get('/login', [LoginController::class, 'create'])->name('login');
    Route::post('/login', [LoginController::class, 'store'])->middleware('throttle:10,1');
});

Route::get('/', [LoginController::class, 'home'])->name('home');

// Bukti transfer dari PDF laporan, dua tahap.
//
// `proofs.link` yang tercetak di dokumen tidak pernah kedaluwarsa — pemegang
// laporan harus selalu bisa membukanya. Yang ia lakukan cuma menerbitkan
// `proofs.view` berumur 60 detik lalu melempar ke sana. Jadi yang mati adalah
// alamat yang mendarat di riwayat browser dan bisa disalin ke mana-mana, bukan
// tautan di dokumennya; mengklik ulang dari dokumen memberi jendela baru.
//
// Nama parameternya sengaja bukan `transaction`: binding global untuk nama itu
// menyaring lewat Auth::id(), yang di sini kosong.
Route::get('/proofs/{proof}', [TransactionController::class, 'proofLink'])
    ->middleware('signed')
    ->name('proofs.link');

Route::get('/proofs/{proof}/view', [TransactionController::class, 'proofView'])
    ->middleware('signed')
    ->name('proofs.view');

Route::middleware('auth')->group(function () {
    Route::post('/logout', [LoginController::class, 'destroy'])->name('logout');

    Route::middleware('admin')->group(function () {
        Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
        Route::put('/profile', [ProfileController::class, 'update'])->name('profile.update');
        Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');

        // Kelola pengguna dan kunci Gemini.
        Route::prefix('admin')->name('admin.')->group(function () {
            Route::get('/', [AdminController::class, 'index'])->name('index');
            Route::post('/users', [AdminController::class, 'storeUser'])->name('users.store');
            Route::put('/users/{user}', [AdminController::class, 'updateUser'])->name('users.update');
            Route::delete('/users/{user}', [AdminController::class, 'destroyUser'])->name('users.destroy');
            Route::post('/gemini-keys', [AdminController::class, 'storeGeminiKey'])->name('gemini.store');
            Route::post('/gemini-keys/{key}/test', [AdminController::class, 'testGeminiKey'])->middleware('throttle:20,1')->name('gemini.test');
            Route::delete('/gemini-keys/{key}', [AdminController::class, 'destroyGeminiKey'])->name('gemini.destroy');
            Route::post('/backup', [AdminController::class, 'backup'])->middleware('throttle:5,1')->name('backup');
            Route::get('/backup/{name}', [AdminController::class, 'downloadBackup'])->name('backup.download');
        });
    });
});
