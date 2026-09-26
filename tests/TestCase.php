<?php

namespace Tests;

use App\Models\Account;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;

abstract class TestCase extends BaseTestCase
{
    private ?Account $apiAccount = null;

    /** Panggilan `api()` berikutnya memakai akun ini, sebagai pemiliknya. */
    protected function onAccount(Account $account): static
    {
        Sanctum::actingAs($account->user);
        $this->apiAccount = $account;

        return $this;
    }

    /**
     * API aplikasi mobile, alamatnya relatif terhadap akun dari onAccount():
     * `api('post', 'trades')` → POST /api/v1/accounts/{id}/trades. Akun dan
     * laporan tidak menempel ke satu akun: `api('get', 'reports')` →
     * GET /api/v1/reports.
     */
    protected function api(string $method, string $path, array $data = []): TestResponse
    {
        $base = preg_match('#^(accounts|reports)\b#', $path)
            ? '/api/v1'
            : "/api/v1/accounts/{$this->apiAccount->id}";

        return $this->json($method, "{$base}/{$path}", $data);
    }
}
