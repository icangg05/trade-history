<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Setup dan catatan milik trade sebelum ia masuk grup. Begitu bergrup, kedua
// field itu dipakai bersama seluruh anggota; salinan ini yang dikembalikan saat
// trade dikeluarkan lagi.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('trades', function (Blueprint $table) {
            $table->json('pre_group')->nullable()->after('group_id');
        });
    }

    public function down(): void
    {
        Schema::table('trades', function (Blueprint $table) {
            $table->dropColumn('pre_group');
        });
    }
};
