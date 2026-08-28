<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            // Kurs saat transaksi terjadi, bukan kurs hari ini — satu-satunya
            // angka yang bikin konversi ke rupiah akurat. Null untuk akun IDR
            // dan untuk baris lama yang dicatat sebelum kolom ini ada.
            $table->decimal('rate_idr', 12, 2)->nullable()->after('amount');
        });
    }

    public function down(): void
    {
        Schema::table('transactions', fn (Blueprint $table) => $table->dropColumn('rate_idr'));
    }
};
