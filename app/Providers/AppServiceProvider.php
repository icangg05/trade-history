<?php

namespace App\Providers;

use App\Models\Account;
use App\Models\Trade;
use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        $this->registerRequestMacros();
        $this->registerScopedRouteBindings();
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
    }

    /**
     * Satu pagar untuk semua route: model hanya bisa di-resolve kalau memang
     * milik user yang login. Tidak perlu cek kepemilikan di tiap controller.
     */
    private function registerScopedRouteBindings(): void
    {
        Route::bind('account', fn ($id) => Account::where('user_id', Auth::id())->findOrFail($id));

        foreach (['trade' => Trade::class, 'transaction' => Transaction::class] as $key => $model) {
            Route::bind($key, fn ($id) => $model::whereHas(
                'account',
                fn ($q) => $q->where('user_id', Auth::id())
            )->findOrFail($id));
        }
    }
}
