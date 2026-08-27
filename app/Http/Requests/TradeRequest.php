<?php

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;

class TradeRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'symbol' => ['required', 'string', 'max:20'],
            'direction' => ['required', 'in:buy,sell'],
            'lot' => ['nullable', 'numeric', 'gt:0', 'max:10000'],
            'entry_price' => ['required', 'numeric', 'gt:0'],
            'sl_price' => ['nullable', 'numeric', 'gt:0'],
            'tp_price' => ['nullable', 'numeric', 'gt:0'],
            'exit_price' => ['nullable', 'numeric', 'gt:0'],
            // Aplikasi ini mencatat riwayat, bukan posisi berjalan: tiap trade
            // yang masuk sudah punya hasil dan waktu tutup.
            'pnl' => ['required', 'numeric'],
            'closed_at' => ['required', 'date', 'after_or_equal:opened_at'],
            'opened_at' => ['required', 'date'],
            'setup' => ['nullable', 'string', 'max:255'],
            'notes' => ['nullable', 'string', 'max:5000'],
            'source' => ['nullable', 'in:manual,ai'],
            // Respons mentah Gemini, disimpan apa adanya sebagai jejak audit.
            'ai_raw' => ['nullable', 'array'],
        ];
    }

    /**
     * Take profit harus berada di sisi yang benar terhadap entry. Output AI lewat
     * validasi yang sama persis dengan input manual — tidak ada jalur istimewa.
     *
     * Stop loss sengaja TIDAK dibatasi sisinya: stop yang digeser ke harga entry
     * (break-even) atau melewatinya (SL+) adalah praktik normal, dan dulu justru
     * membuat trade seperti itu tidak bisa dicatat sama sekali. Keadaannya
     * dijelaskan lewat `Trade::stopState()`, bukan ditolak.
     */
    public function after(): array
    {
        return [
            function (Validator $validator) {
                $entry = $this->nullableFloat('entry_price');
                $tp = $this->nullableFloat('tp_price');

                if ($entry === null) {
                    return;
                }

                $isBuy = $this->input('direction') === 'buy';

                if ($tp !== null && $tp !== $entry && ($tp > $entry) !== $isBuy) {
                    $validator->errors()->add('tp_price', $isBuy
                        ? 'Untuk posisi buy, take profit harus di atas harga entry.'
                        : 'Untuk posisi sell, take profit harus di bawah harga entry.');
                }
            },
        ];
    }

    private function nullableFloat(string $key): ?float
    {
        $value = $this->input($key);

        return ($value === null || $value === '') ? null : (float) $value;
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'symbol' => strtoupper(trim((string) $this->input('symbol'))),
        ]);
    }
}
