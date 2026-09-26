<?php

namespace App\Providers;

use App\Models\Account;
use App\Models\Trade;
use App\Models\Transaction;
use App\Models\User;
use App\Support\Hashid;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;
use Laravel\Sanctum\PersonalAccessToken;
use Laravel\Sanctum\Sanctum;

class AppServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        $this->registerRequestMacros();
        $this->registerScopedRouteBindings();
        $this->registerApiGuards();
    }

    private function registerApiGuards(): void
    {
        // Masa berlaku bergeser: dihitung dari terakhir dipakai, bukan dari
        // saat login. Yang membuka aplikasi tiap minggu tidak pernah dipaksa
        // login ulang; ponsel yang hilang atau ditinggal mati sendiri.
        Sanctum::authenticateAccessTokensUsing(
            fn (PersonalAccessToken $token, bool $isValid) => $isValid
                && ($token->last_used_at ?? $token->created_at)->gt(now()->subDays(User::TOKEN_IDLE_DAYS))
        );

        // Batas umum semua API, per pengguna (per IP sebelum login). Longgar:
        // satu layar Dana bisa memuat puluhan thumbnail bukti sekaligus, dan
        // tiap thumbnail satu permintaan. Rute berat punya batas sendiri.
        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(300)->by($request->user()?->id ?: $request->ip()));
    }

    /** Akun aktif diisi oleh SetCurrentAccount; dibaca lewat dua macro ini. */
    private function registerRequestMacros(): void
    {
        Request::macro('currentAccount', function (): ?Account {
            /** @var Request $this */
            return $this->attributes->get('current_account');
        });

        Request::macro('accountList', function (): Collection {
            /** @var Request $this */
            return $this->attributes->get('account_list') ?? collect();
        });

        // Permintaan dari aplikasi mobile: dijawab JSON, tanpa sesi maupun flash.
        Request::macro('isApi', function (): bool {
            /** @var Request $this */
            return $this->is('api/*');
        });
    }

    /**
     * Satu pagar untuk semua route: model hanya bisa di-resolve kalau memang
     * milik user yang login. Tidak perlu cek kepemilikan di tiap controller.
     *
     * Di sini pula hash dari URL dikembalikan jadi id. Hash yang tidak sah
     * mendekode ke 0 dan berakhir sebagai 404, sama seperti id yang tidak ada.
     */
    private function registerScopedRouteBindings(): void
    {
        Route::bind('account', fn ($id) => Account::where('user_id', Auth::id())->findOrFail($id));

        foreach (['trade' => Trade::class, 'transaction' => Transaction::class] as $key => $model) {
            Route::bind($key, fn ($hash) => $model::whereHas(
                'account',
                fn ($q) => $q->where('user_id', Auth::id())
            )->findOrFail(Hashid::decode($hash)));
        }
    }
}
