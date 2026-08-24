<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_admin')->default(false)->after('password');
        });

        // Pengguna pertama otomatis jadi admin, kalau tidak halaman /admin
        // tidak bisa dibuka siapa pun setelah migrasi ini jalan.
        DB::table('users')->orderBy('id')->limit(1)->update(['is_admin' => true]);

        // Satu baris saja: kunci Gemini yang dipakai seluruh aplikasi.
        // Kuncinya disimpan terenkripsi (cast `encrypted` di model).
        Schema::create('gemini_settings', function (Blueprint $table) {
            $table->id();
            $table->text('api_key')->nullable();
            $table->string('model')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('gemini_settings');
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn('is_admin'));
    }
};
