<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use App\Services\Uploads;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Laravel\Sanctum\PersonalAccessToken;

#[Fillable(['name', 'email', 'password', 'is_admin'])]
#[Hidden(['password', 'remember_token', 'avatar_path'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /** Token mobile yang tidak dipakai selama ini dianggap mati (lihat AppServiceProvider). */
    public const TOKEN_IDLE_DAYS = 30;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_admin' => 'boolean',
        ];
    }

    /**
     * Token aplikasi mobile terikat lewat relasi morph, bukan foreign key, jadi
     * tidak ikut terhapus oleh cascade. Dibuang di sini supaya pengguna yang
     * dihapus — oleh dirinya sendiri maupun oleh admin — tidak meninggalkan
     * token yang masih bisa dipakai. Berkas di disk juga: folder foto profil
     * dibuang, dan akun trading dihapus satu per satu (bukan lewat cascade)
     * supaya folder bukti transaksinya ikut terbuang — lihat Account::booted().
     */
    protected static function booted(): void
    {
        // Sandi berganti — oleh pemiliknya, oleh admin, atau lewat lupa sandi —
        // berarti semua token lama dicabut. Hanya token yang sedang dipakai
        // untuk menggantinya yang dibiarkan, supaya ponsel itu tetap masuk.
        static::updated(function (User $user) {
            if ($user->wasChanged('password')) {
                $current = $user->currentAccessToken();

                $user->tokens()
                    ->when($current instanceof PersonalAccessToken, fn ($q) => $q->whereKeyNot($current->getKey()))
                    ->delete();
            }
        });

        static::deleting(function (User $user) {
            $user->tokens()->delete();
            $user->accounts->each->delete();
            Uploads::deleteFolder($user->uploadFolder());
        });
    }

    /** Folder foto profil pengguna ini di disk Uploads. */
    public function uploadFolder(): string
    {
        return 'avatars/'.$this->id;
    }

    /**
     * Penanda versi foto profil untuk aplikasi mobile. Alamat fotonya selalu
     * sama, jadi tanpa penanda ini ponsel terus menampilkan foto lama dari
     * cache-nya. Berubah setiap kali foto diganti, null kalau belum ada foto.
     */
    public function avatarVersion(): ?string
    {
        return $this->avatar_path ? substr(md5($this->avatar_path), 0, 8) : null;
    }

    public function accounts(): HasMany
    {
        return $this->hasMany(Account::class);
    }
}
