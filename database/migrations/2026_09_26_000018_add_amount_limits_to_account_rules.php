<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('account_rules', function (Blueprint $table) {
            // Risiko per trade dan drawdown sebagai nominal, bukan persen. Kolom
            // persennya tetap ada untuk aturan lama; nominal didahulukan.
            $table->decimal('max_risk_per_trade', 18, 2)->nullable()->after('max_risk_per_trade_pct');
            $table->decimal('max_total_loss', 18, 2)->nullable()->after('max_total_loss_pct');
        });
    }

    public function down(): void
    {
        Schema::table('account_rules', fn (Blueprint $table) => $table->dropColumn(['max_risk_per_trade', 'max_total_loss']));
    }
};
