<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Satu kunci Gemini diganti banyak kunci bernama. Model dan batas kuota ikut
 * hilang: kuota tidak lagi dihitung sendiri, pemakaian digilir antar kunci
 * dengan jeda pendinginan (lihat App\Models\GeminiKey).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('gemini_keys', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('api_key');
            // Kapan kunci ini terakhir dipakai — dasar penggiliran.
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();
        });

        // Kunci lama ikut pindah apa adanya: ciphertext-nya tetap sah karena
        // kunci aplikasi yang mengenkripsinya tidak berubah.
        if (Schema::hasTable('gemini_settings')) {
            $old = DB::table('gemini_settings')->whereNotNull('api_key')->value('api_key');

            if ($old) {
                DB::table('gemini_keys')->insert([
                    'name' => 'Kunci utama',
                    'api_key' => $old,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            Schema::drop('gemini_settings');
        }
    }

    public function down(): void
    {
        Schema::create('gemini_settings', function (Blueprint $table) {
            $table->id();
            $table->text('api_key')->nullable();
            $table->string('model')->nullable();
            $table->unsignedInteger('rpm')->nullable();
            $table->unsignedInteger('tpm')->nullable();
            $table->unsignedInteger('rpd')->nullable();
            $table->timestamps();
        });

        Schema::dropIfExists('gemini_keys');
    }
};
