<?php

namespace App\Http\Middleware;

use App\Models\Account;
use App\Models\Trade;
use App\Models\Transaction;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Padanan SetCurrentAccount untuk aplikasi mobile. API tidak punya sesi, jadi
 * akun yang dibuka ikut di alamatnya (`/api/v1/accounts/{account}/…`) dan
 * dipasang ke request lewat macro yang sama — controller web tidak perlu tahu
 * dari mana akunnya datang.
 *
 * Kepemilikan akun sudah dicek `Route::bind('account')`. Yang ditambahkan di
 * sini: trade dan transaksi harus milik akun di alamat itu, bukan sekadar milik
 * pengguna yang sama — kalau tidak, menghapus lewat akun A bisa mengenai baris
 * akun B.
 */
class UseRouteAccount
{
    public function handle(Request $request, Closure $next): Response
    {
        $route = $request->route();
        $account = $route->parameter('account');

        // Akun arsip tidak bisa dibuka di web (SetCurrentAccount melewatinya),
        // jadi di aplikasi pun tidak. Mengeluarkannya dari arsip lewat daftar akun.
        abort_unless($account instanceof Account && ! $account->is_archived, 404);

        foreach (['trade', 'transaction'] as $key) {
            $model = $route->parameter($key);

            abort_if(($model instanceof Trade || $model instanceof Transaction) && $model->account_id !== $account->id, 404);
        }

        // Dilepas dari parameter rute: controller web tidak menerima `$account`,
        // dan parameter ekstra akan menggeser argumen yang ia harapkan.
        $route->forgetParameter('account');

        $request->attributes->set('current_account', $account->loadMissing('rule'));

        return $next($request);
    }
}
