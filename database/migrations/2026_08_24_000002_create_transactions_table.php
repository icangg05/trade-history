<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('account_id')->constrained()->cascadeOnDelete();
            $table->enum('type', ['deposit', 'withdrawal']);
            $table->decimal('amount', 18, 2);
            $table->date('occurred_at');
            // Bukti transfer. Wajib lewat form (lihat TransactionController);
            // nullable di DB supaya data seeder/lama tetap valid.
            $table->string('proof_path')->nullable();
            $table->text('note')->nullable();
            $table->timestamps();

            $table->index(['account_id', 'occurred_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('transactions');
    }
};
