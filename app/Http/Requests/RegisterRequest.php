<?php

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

/**
 * Pendaftaran mandiri, dari browser maupun aplikasi mobile. Hanya terbuka kalau
 * REGISTER_TOKEN diisi di .env; tanpa itu pintunya dijawab 404 — sebelum satu
 * isian pun divalidasi, supaya keberadaannya tidak bocor lewat pesan galat.
 */
class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return filled(config('auth.register_token'));
    }

    protected function failedAuthorization(): void
    {
        abort(404);
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:60'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::min(8)],
            'token' => ['required', 'string'],
        ];
    }

    /**
     * Dibandingkan dengan hash_equals: waktu bandingnya tetap sama berapa pun
     * karakter yang benar, jadi token tidak bisa ditebak sepotong demi sepotong.
     */
    public function after(): array
    {
        return [
            function (Validator $validator) {
                $token = $this->input('token');

                if (is_string($token) && filled($token) && ! hash_equals((string) config('auth.register_token'), $token)) {
                    $validator->errors()->add('token', 'Token pendaftaran tidak cocok.');
                }
            },
        ];
    }

    /** Isian yang boleh masuk ke tabel users — token hanya kunci pintu. */
    public function account(): array
    {
        return $this->safe()->except('token');
    }
}
