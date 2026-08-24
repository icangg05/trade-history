<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('account_rules', function (Blueprint $table) {
            $table->foreignId('account_id')->primary()->constrained()->cascadeOnDelete();

            // Batas — semua nullable, dipakai hanya untuk indikator (tidak memblokir input).
            $table->decimal('max_daily_loss', 18, 2)->nullable();
            $table->decimal('max_daily_loss_pct', 5, 2)->nullable();
            $table->decimal('daily_profit_target', 18, 2)->nullable();
            $table->decimal('daily_profit_target_pct', 5, 2)->nullable();
            $table->decimal('max_total_loss_pct', 5, 2)->nullable();
            $table->decimal('max_risk_per_trade_pct', 5, 2)->nullable();
            $table->unsignedTinyInteger('max_trades_per_day')->nullable();
            $table->decimal('min_rr', 4, 2)->nullable();
            $table->json('allowed_sessions')->nullable();

            $table->longText('notes')->nullable(); // markdown bebas
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('account_rules');
    }
};
