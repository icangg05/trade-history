<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            // Kurs deposit/withdrawal dicatat sampai tiga angka di belakang koma
            // (16.250,125) — sama persis dengan yang tertera di bukti transfer.
            $table->decimal('rate_idr', 13, 3)->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->decimal('rate_idr', 12, 2)->nullable()->change();
        });
    }
};
