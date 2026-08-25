<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Satu ide trading sering dieksekusi berlapis: beberapa entry di harga berbeda
// dengan setup, arah, SL, dan TP yang sama. Layer-layernya disimpan di sini;
// `entry_price` dan `lot` tetap jadi ringkasannya (rata-rata terboboti & total)
// supaya semua hitungan lain tidak perlu tahu soal layer.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('trades', function (Blueprint $table) {
            $table->json('entries')->nullable()->after('entry_price');
        });
    }

    public function down(): void
    {
        Schema::table('trades', function (Blueprint $table) {
            $table->dropColumn('entries');
        });
    }
};
