<?php

namespace Database\Seeders;

use App\Models\Account;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Database\Seeder;

/**
 * Data contoh untuk mencoba tampilan. Jalankan: php artisan db:seed --class=DemoSeeder
 */
class DemoSeeder extends Seeder
{
    public function run(): void
    {
        $user = User::firstOrFail();

        $account = Account::updateOrCreate(
            ['user_id' => $user->id, 'name' => 'Demo XAUUSD'],
            [
                'broker' => 'Exness',
                'currency' => 'USC',        // akun sen — 5000 USC ≈ 50 USD
                'initial_balance' => 5000,
                'started_at' => CarbonImmutable::now()->subMonths(8)->startOfMonth(),
            ],
        );

        $account->trades()->delete();
        $account->transactions()->delete();

        $account->rule()->updateOrCreate([], [
            'max_daily_loss_pct' => 3,
            'daily_profit_target_pct' => 2,
            'max_total_loss_pct' => 10,
            'max_risk_per_trade_pct' => 1,
            'max_trades_per_day' => 3,
            'min_rr' => 1.5,
            'allowed_sessions' => ['london', 'newyork'],
            'notes' => "## Checklist sebelum entry\n- Cek kalender news\n- Konfirmasi struktur H4\n- Risiko maksimal 1% per posisi\n\n## Pantangan\n- Tidak entry setelah 2 loss beruntun\n- Tidak menggeser stop loss menjauh",
        ]);

        // Tanpa proof_path: form mewajibkan bukti, tapi data contoh tidak punya berkas.
        $account->transactions()->createMany([
            ['type' => 'deposit', 'amount' => 2000, 'occurred_at' => CarbonImmutable::now()->subMonths(5), 'note' => 'Top up'],
            ['type' => 'withdrawal', 'amount' => 800, 'occurred_at' => CarbonImmutable::now()->subMonths(2), 'note' => 'Ambil profit'],
        ]);

        $symbols = ['XAUUSD', 'EURUSD', 'GBPUSD', 'USDJPY'];
        $setups = ['Break of structure', 'Order block', 'Liquidity sweep', null];
        $day = CarbonImmutable::now()->subMonths(8)->startOfMonth();

        while ($day < CarbonImmutable::now()) {
            $day = $day->addDay();

            if ($day->isWeekend() || random_int(1, 100) > 55) {
                continue;
            }

            foreach (range(1, random_int(1, 3)) as $ignored) {
                $symbol = $symbols[array_rand($symbols)];
                $isBuy = (bool) random_int(0, 1);
                $entry = round(match ($symbol) {
                    'XAUUSD' => random_int(230000, 245000) / 100,
                    'USDJPY' => random_int(14500, 15800) / 100,
                    default => random_int(105000, 130000) / 100000,
                }, 5);

                $risk = $entry * (random_int(15, 45) / 10000);
                $rr = random_int(10, 35) / 10;
                $sign = $isBuy ? 1 : -1;
                $won = random_int(1, 100) <= 52;
                $opened = $day->setTime(random_int(13, 22), random_int(0, 59));

                $account->trades()->create([
                    'symbol' => $symbol,
                    'direction' => $isBuy ? 'buy' : 'sell',
                    'lot' => random_int(2, 20) / 100,
                    'entry_price' => $entry,
                    'sl_price' => round($entry - $sign * $risk, 5),
                    'tp_price' => round($entry + $sign * $risk * $rr, 5),
                    'exit_price' => round($entry + $sign * $risk * ($won ? $rr : -1), 5),
                    // Besaran menang/kalah dijaga di rentang 80-300 USC.
                    'pnl' => $won ? random_int(120, 300) : -random_int(80, 220),
                    'opened_at' => $opened,
                    'closed_at' => $opened->addHours(random_int(1, 8)),
                    'setup' => $setups[array_rand($setups)],
                ]);
            }
        }

        $this->command->info('Demo: '.$account->trades()->count().' trade dibuat di akun "'.$account->name.'".');
    }
}
