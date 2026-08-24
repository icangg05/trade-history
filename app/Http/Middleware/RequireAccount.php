<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Halaman yang butuh akun aktif. Belum punya akun → dilempar ke daftar akun. */
class RequireAccount
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->currentAccount()) {
            return redirect()
                ->route('accounts.index')
                ->with('info', 'Buat satu akun trading dulu untuk mulai mencatat.');
        }

        return $next($request);
    }
}
