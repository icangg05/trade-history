<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Penanda bahwa beberapa trade berurutan lahir dari satu ide yang sama. Tidak
// ada nama dan tidak ada tabel grup: kuncinya id trade paling awal di grup itu,
// dan tiap trade tetap berdiri sendiri dengan waktu tutup serta P/L masing-masing.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('trades', function (Blueprint $table) {
            $table->unsignedBigInteger('group_id')->nullable()->after('setup');
            $table->index(['account_id', 'group_id']);
        });
    }

    public function down(): void
    {
        Schema::table('trades', function (Blueprint $table) {
            $table->dropIndex(['account_id', 'group_id']);
            $table->dropColumn('group_id');
        });
    }
};
