<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('trades', function (Blueprint $table) {
            $table->id();
            $table->foreignId('account_id')->constrained()->cascadeOnDelete();
            $table->string('symbol', 20);
            $table->enum('direction', ['buy', 'sell']);
            $table->decimal('lot', 10, 2)->nullable();
            $table->decimal('entry_price', 18, 5)->nullable();
            $table->decimal('sl_price', 18, 5)->nullable();
            $table->decimal('tp_price', 18, 5)->nullable();
            $table->decimal('exit_price', 18, 5)->nullable();
            $table->decimal('pnl', 18, 2)->nullable();     // null = posisi masih terbuka
            $table->decimal('pips', 10, 1)->nullable();
            $table->decimal('rr_planned', 6, 2)->nullable();
            $table->decimal('rr_realized', 6, 2)->nullable();
            $table->enum('status', ['open', 'win', 'loss', 'be'])->default('open');
            $table->dateTime('opened_at');
            $table->dateTime('closed_at')->nullable();
            $table->string('setup', 50)->nullable();
            $table->json('tags')->nullable();
            $table->text('notes')->nullable();
            $table->enum('source', ['manual', 'ai'])->default('manual');
            // Gambar tidak ikut disimpan; ai_raw adalah satu-satunya jejak
            // apa yang dibaca AI dari screenshot.
            $table->json('ai_raw')->nullable();
            $table->timestamps();

            $table->index(['account_id', 'opened_at']);
            $table->index(['account_id', 'status']);
            $table->index(['account_id', 'symbol']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trades');
    }
};
