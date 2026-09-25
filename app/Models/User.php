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

#[Fillable(['name', 'email', 'password', 'is_admin'])]
#[Hidden(['password', 'remember_token', 'avatar_path'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

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
     * token yang masih bisa dipakai. Foto profil juga: berkasnya di disk, tidak
     * ikut hilang bersama barisnya.
     */
    protected static function booted(): void
    {
        static::deleting(function (User $user) {
            $user->tokens()->delete();
            Uploads::delete($user->avatar_path);
        });
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
