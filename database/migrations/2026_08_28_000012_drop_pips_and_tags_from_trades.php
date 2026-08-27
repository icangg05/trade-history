<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Dua kolom yang tidak pernah hidup: `pips` tidak pernah diisi oleh jalur simpan
 * mana pun, dan `tags` tidak pernah punya field di form — nilainya divalidasi dan
 * ditampilkan, tapi tidak ada cara mengisinya. Penandaan strategi sudah dikerjakan
 * `setup` (koma-pisah lewat SetupPicker).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('trades', function (Blueprint $table) {
            $table->dropColumn(['pips', 'tags']);
        });
    }

    public function down(): void
    {
        Schema::table('trades', function (Blueprint $table) {
            $table->decimal('pips', 10, 1)->nullable()->after('pnl');
            $table->json('tags')->nullable()->after('setup');
        });
    }
};
