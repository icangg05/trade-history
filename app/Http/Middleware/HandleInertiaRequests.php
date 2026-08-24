<?php

namespace App\Http\Middleware;

use Illuminate\Http\Request;
use Inertia\Middleware;

class HandleInertiaRequests extends Middleware
{
    protected $rootView = 'app';

    public function share(Request $request): array
    {
        $account = $request->currentAccount();

        return [
            ...parent::share($request),

            'auth' => [
                'user' => $request->user()?->only('id', 'name', 'email', 'is_admin'),
            ],

            'accounts' => fn () => $request->accountList()->map->only('id', 'name', 'broker', 'currency'),

            'currentAccount' => fn () => $account?->only('id', 'name', 'broker', 'currency', 'initial_balance', 'started_at'),

            'flash' => [
                'success' => fn () => $request->session()->get('success'),
                'error' => fn () => $request->session()->get('error'),
                'info' => fn () => $request->session()->get('info'),
            ],
        ];
    }
}
