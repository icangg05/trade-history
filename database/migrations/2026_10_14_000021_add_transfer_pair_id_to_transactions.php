<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            // Transfer antar akun dicatat sebagai withdrawal di akun asal dan
            // deposit di akun tujuan; keduanya saling menunjuk lewat kolom ini.
            // Kalau akun di seberang dihapus, sisi yang tersisa jadi transaksi
            // biasa — uangnya tetap ada di akun ini.
            $table->foreignId('transfer_pair_id')->nullable()->after('note')
                ->constrained('transactions')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropConstrainedForeignId('transfer_pair_id');
        });
    }
};
