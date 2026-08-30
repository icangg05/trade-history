<?php

namespace Tests\Feature;

use App\Models\Account;
use App\Models\Trade;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Grup hanya penanda "trade-trade berurutan ini lahir dari satu ide": tiap
 * trade tetap berdiri sendiri dengan waktu tutup dan P/L masing-masing, tapi
 * setup dan catatannya dipegang bersama.
 */
class TradeGroupTest extends TestCase
{
    use RefreshDatabase;

    private function account(): Account
    {
        return User::factory()->create()->accounts()->create([
            'name' => 'Uji',
            'currency' => 'USD',
            'initial_balance' => 1000,
            'started_at' => '2026-01-01',
        ]);
    }

    private function actAs(Account $account): void
    {
        $this->actingAs($account->user)->withSession(['current_account_id' => $account->id]);
    }

    public function test_grouping_menyamakan_setup_dan_catatan_tanpa_menghapus_trade(): void
    {
        $account = $this->account();
        $this->actAs($account);

        $first = $this->trade($account, '10:00', 'Order Block', 'Masuk setelah sweep');
        $second = $this->trade($account, '10:30', 'FVG, Order Block', 'Tambah saat pullback.');

        $this->post('/trades/group', ['ids' => [$first->getRouteKey(), $second->getRouteKey()]])->assertSessionHas('success');

        $first->refresh();
        $second->refresh();

        // Semua strategi anggota grup tercentang di tiap trade.
        $this->assertSame('Order Block, FVG', $first->setup);
        $this->assertSame($first->setup, $second->setup);

        // Catatan disambung jadi satu, tiap bagian diakhiri titik.
        $this->assertSame('Masuk setelah sweep. Tambah saat pullback.', $first->notes);
        $this->assertSame($first->notes, $second->notes);

        // Kuncinya id trade paling awal, dan tiap trade tetap berdiri sendiri.
        $this->assertSame($first->id, $first->group_id);
        $this->assertSame($first->id, $second->group_id);
        $this->assertSame(2, Trade::count());
        $this->assertSame('2026-01-02 10:00:00', $first->opened_at->toDateTimeString());
        $this->assertSame('2026-01-02 10:30:00', $second->opened_at->toDateTimeString());
    }

    public function test_trade_yang_tidak_berurutan_ditolak(): void
    {
        $account = $this->account();
        $this->actAs($account);

        $first = $this->trade($account, '10:00');
        $this->trade($account, '10:30');
        $third = $this->trade($account, '11:00');

        $this->post('/trades/group', ['ids' => [$first->getRouteKey(), $third->getRouteKey()]])->assertSessionHas('error');

        $this->assertSame(0, Trade::whereNotNull('group_id')->count());
    }

    public function test_setup_dan_catatan_grup_diisi_sekali_untuk_semua_anggota(): void
    {
        $account = $this->account();
        $this->actAs($account);

        $first = $this->trade($account, '10:00');
        $second = $this->trade($account, '10:30');
        $this->post('/trades/group', ['ids' => [$first->getRouteKey(), $second->getRouteKey()]]);

        $this->put("/trades/group/{$first->getRouteKey()}", ['setup' => 'CHoCH, FVG', 'notes' => 'Ide satu sesi.'])
            ->assertSessionHas('success');

        $this->assertSame('CHoCH, FVG', $second->refresh()->setup);
        $this->assertSame('Ide satu sesi.', $second->notes);
    }

    public function test_setup_dan_catatan_tidak_bisa_diubah_dari_form_trade_bergrup(): void
    {
        $account = $this->account();
        $this->actAs($account);

        $first = $this->trade($account, '10:00', 'Order Block', 'Catatan grup.');
        $second = $this->trade($account, '10:30', 'Order Block', 'Catatan grup.');
        $this->post('/trades/group', ['ids' => [$first->getRouteKey(), $second->getRouteKey()]]);

        $this->put("/trades/{$second->getRouteKey()}", [
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 111,
            'opened_at' => '2026-01-02 10:30',
            'closed_at' => '2026-01-02 12:00',
            'pnl' => 50,
            'setup' => 'Breakout',
            'notes' => 'Catatan sendiri.',
        ])->assertSessionHasNoErrors();

        $second->refresh();

        $this->assertSame(111.0, (float) $second->entry_price);   // field lain tetap bisa diubah
        $this->assertSame('Order Block', $second->setup);
        $this->assertSame('Catatan grup.', $second->notes);
    }

    public function test_trade_bisa_dikeluarkan_dan_grup_sisa_satu_ikut_bubar(): void
    {
        $account = $this->account();
        $this->actAs($account);

        $first = $this->trade($account, '10:00');
        $second = $this->trade($account, '10:30');
        $third = $this->trade($account, '11:00');
        $this->post('/trades/group', ['ids' => [$first->getRouteKey(), $second->getRouteKey(), $third->getRouteKey()]]);

        $this->delete("/trades/{$third->getRouteKey()}/group")->assertSessionHas('success');

        $this->assertNull($third->refresh()->group_id);
        $this->assertSame(2, Trade::whereNotNull('group_id')->count());

        // Tinggal satu anggota → bukan grup lagi.
        $this->delete("/trades/{$second->getRouteKey()}/group");

        $this->assertSame(0, Trade::whereNotNull('group_id')->count());
    }

    public function test_setup_dan_catatan_asli_kembali_saat_dikeluarkan(): void
    {
        $account = $this->account();
        $this->actAs($account);

        $first = $this->trade($account, '10:00', 'Order Block', 'Catatan pertama.');
        $second = $this->trade($account, '10:30', 'FVG', 'Catatan kedua.');
        $this->post('/trades/group', ['ids' => [$first->getRouteKey(), $second->getRouteKey()]]);

        // Grupnya sempat diubah pula — yang dikembalikan tetap punya trade itu.
        $this->put("/trades/group/{$first->getRouteKey()}", ['setup' => 'CHoCH', 'notes' => 'Catatan grup.']);

        $this->delete("/trades/{$second->getRouteKey()}/group")->assertSessionHas('success');

        $second->refresh();

        $this->assertNull($second->group_id);
        $this->assertSame('FVG', $second->setup);
        $this->assertSame('Catatan kedua.', $second->notes);

        // Sisanya tinggal satu → ikut bubar, dan ikut kembali ke aslinya.
        $first->refresh();

        $this->assertNull($first->group_id);
        $this->assertSame('Order Block', $first->setup);
        $this->assertSame('Catatan pertama.', $first->notes);
    }

    public function test_trade_di_tengah_grup_tidak_bisa_dikeluarkan(): void
    {
        $account = $this->account();
        $this->actAs($account);

        $first = $this->trade($account, '10:00');
        $middle = $this->trade($account, '10:30');
        $last = $this->trade($account, '11:00');
        $this->post('/trades/group', ['ids' => [$first->getRouteKey(), $middle->getRouteKey(), $last->getRouteKey()]]);

        $this->delete("/trades/{$middle->getRouteKey()}/group")->assertSessionHas('error');

        $this->assertSame($first->id, $middle->refresh()->group_id);
        $this->assertSame(3, Trade::whereNotNull('group_id')->count());

        // Dari ujung boleh — sesudah itu yang tadi di tengah jadi ujung.
        $this->delete("/trades/{$last->getRouteKey()}/group")->assertSessionHas('success');
        $this->delete("/trades/{$middle->getRouteKey()}/group")->assertSessionHas('success');

        $this->assertSame(0, Trade::whereNotNull('group_id')->count());
    }

    public function test_trade_bisa_ditambahkan_ke_grup_yang_sudah_ada(): void
    {
        $account = $this->account();
        $this->actAs($account);

        $first = $this->trade($account, '10:00', 'Order Block', 'Catatan pertama.');
        $second = $this->trade($account, '10:30', 'FVG', 'Catatan kedua.');
        $third = $this->trade($account, '11:00', 'Breakout', 'Catatan ketiga.');
        $this->post('/trades/group', ['ids' => [$first->getRouteKey(), $second->getRouteKey()]]);

        // Anggota lama ikut dipilih; itulah cara menambah trade ke grup itu.
        $this->post('/trades/group', ['ids' => [$second->getRouteKey(), $third->getRouteKey()]])->assertSessionHas('success');

        $this->assertSame($first->id, $third->refresh()->group_id);   // kunci grup lama dipakai
        $this->assertSame(3, Trade::where('group_id', $first->id)->count());
        $this->assertSame('Order Block, FVG, Breakout', $third->setup);

        // Salinan asli anggota lama tidak tertimpa oleh nilai grup.
        $this->assertSame(['setup' => 'FVG', 'notes' => 'Catatan kedua.'], $second->refresh()->pre_group);
        $this->assertSame(['setup' => 'Breakout', 'notes' => 'Catatan ketiga.'], $third->pre_group);
    }

    public function test_pilihan_yang_menyentuh_dua_grup_ditolak(): void
    {
        $account = $this->account();
        $this->actAs($account);

        $a1 = $this->trade($account, '10:00');
        $a2 = $this->trade($account, '10:30');
        $b1 = $this->trade($account, '11:00');
        $b2 = $this->trade($account, '11:30');
        $this->post('/trades/group', ['ids' => [$a1->getRouteKey(), $a2->getRouteKey()]]);
        $this->post('/trades/group', ['ids' => [$b1->getRouteKey(), $b2->getRouteKey()]]);

        $this->post('/trades/group', ['ids' => [$a2->getRouteKey(), $b1->getRouteKey()]])->assertSessionHas('error');

        $this->assertSame($a1->id, $a2->refresh()->group_id);
        $this->assertSame($b1->id, $b1->refresh()->group_id);
    }

    public function test_grouping_trade_akun_lain_ditolak(): void
    {
        $mine = $this->account();
        $others = $this->account();
        $this->actAs($mine);

        $ids = [$this->trade($mine, '10:00')->getRouteKey(), $this->trade($others, '10:30')->getRouteKey()];

        $this->post('/trades/group', ['ids' => $ids])->assertSessionHas('error');

        $this->assertSame(0, Trade::whereNotNull('group_id')->count());
    }

    private function trade(Account $account, string $time, ?string $setup = null, ?string $notes = null): Trade
    {
        return $account->trades()->create([
            'symbol' => 'XAUUSD',
            'direction' => 'buy',
            'entry_price' => 100,
            'sl_price' => 90,
            'pnl' => 50,
            'setup' => $setup,
            'notes' => $notes,
            'opened_at' => '2026-01-02 '.$time,
            'closed_at' => '2026-01-02 12:00',
        ]);
    }
}
