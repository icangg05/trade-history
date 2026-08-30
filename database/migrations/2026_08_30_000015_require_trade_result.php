<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Aplikasi ini mencatat riwayat, bukan posisi berjalan: `TradeRequest` sudah
 * mewajibkan `pnl` dan `closed_at`, dan `Trade::computeStatus()` tidak pernah
 * bisa mengembalikan `open`. Skema masih mengizinkan keduanya, jadi ada keadaan
 * yang tidak mungkin lahir tapi tetap harus dijaga di setiap query. Dihapus.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('trades', function (Blueprint $table) {
            $table->decimal('pnl', 18, 2)->nullable(false)->change();
            $table->enum('status', ['win', 'loss', 'be'])->default('be')->change();
        });
    }

    public function down(): void
    {
        Schema::table('trades', function (Blueprint $table) {
            $table->decimal('pnl', 18, 2)->nullable()->change();
            $table->enum('status', ['open', 'win', 'loss', 'be'])->default('open')->change();
        });
    }
};
