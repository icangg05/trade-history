<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('accounts', function (Blueprint $table) {
            // Nomor akun di sisi broker. Ini satu-satunya penanda yang menyambungkan
            // laporan tahunan ke statement resmi broker; tanpa itu pemeriksa tidak
            // bisa memastikan kedua dokumen membicarakan akun yang sama.
            $table->string('account_number', 40)->nullable()->after('broker');
        });
    }

    public function down(): void
    {
        Schema::table('accounts', fn (Blueprint $table) => $table->dropColumn('account_number'));
    }
};
