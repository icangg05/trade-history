<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Halaman trading. Admin adalah peran pengelola — mengurus pengguna dan kunci
 * Gemini, bukan mencatat trade — jadi dialihkan ke wilayahnya sendiri.
 */
class EnsureTrader
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->user()?->is_admin) {
            // Aplikasi mobile hanya berisi jurnal; pengelolaan tetap di /admin.
            if ($request->isApi()) {
                return response()->json(['message' => 'Akun admin tidak dipakai untuk mencatat trade.'], 403);
            }

            return redirect()
                ->route('admin.index')
                ->with('info', 'Akun admin tidak dipakai untuk mencatat trade.');
        }

        return $next($request);
    }
}
