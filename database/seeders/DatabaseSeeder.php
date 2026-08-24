<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Sandi hanya ditulis kalau SEED_USER_PASSWORD diisi — menjalankan ulang
        // seeder pada database yang sudah hidup tidak boleh mengunci pemiliknya.
        $password = env('SEED_USER_PASSWORD');

        User::updateOrCreate(
            ['email' => env('SEED_USER_EMAIL', 'admin@example.com')],
            array_filter([
                'name' => env('SEED_USER_NAME', 'Trader'),
                'password' => filled($password) ? $password : null,
                // Pengguna pertama memegang halaman /admin.
                'is_admin' => true,
            ], fn ($value) => $value !== null),
        );

        $this->command->info('User siap. Login dengan '.env('SEED_USER_EMAIL', 'admin@example.com'));
    }
}
