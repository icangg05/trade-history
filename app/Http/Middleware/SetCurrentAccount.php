<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Menentukan akun yang sedang dibuka (dari session, fallback ke akun pertama)
 * dan menempelkannya ke request lewat macro `currentAccount()` / `accountList()`.
 */
class SetCurrentAccount
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user) {
            $accounts = $user->accounts()->where('is_archived', false)->orderBy('name')->get();
            $selected = $request->session()->get('current_account_id');
            $account = $accounts->firstWhere('id', $selected) ?? $accounts->first();

            if ($account && $account->id !== $selected) {
                $request->session()->put('current_account_id', $account->id);
            }

            $request->attributes->set('account_list', $accounts);
            $request->attributes->set('current_account', $account?->loadMissing('rule'));
        }

        return $next($request);
    }
}
