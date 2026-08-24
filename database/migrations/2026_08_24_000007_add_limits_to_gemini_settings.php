<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Batas kuota ikut pindah ke database: satu tempat untuk semua setelan Gemini,
 * bisa diubah admin tanpa menyentuh .env atau menyalakan ulang kontainer.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('gemini_settings', function (Blueprint $table) {
            $table->unsignedInteger('rpm')->nullable()->after('model');
            $table->unsignedInteger('tpm')->nullable()->after('rpm');
            $table->unsignedInteger('rpd')->nullable()->after('tpm');
        });
    }

    public function down(): void
    {
        Schema::table('gemini_settings', fn (Blueprint $table) => $table->dropColumn(['rpm', 'tpm', 'rpd']));
    }
};
