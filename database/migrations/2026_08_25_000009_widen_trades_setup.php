<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Satu trade bisa memakai beberapa strategi sekaligus, disimpan dipisah koma.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('trades', function (Blueprint $table) {
            $table->string('setup', 255)->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('trades', function (Blueprint $table) {
            $table->string('setup', 50)->nullable()->change();
        });
    }
};
