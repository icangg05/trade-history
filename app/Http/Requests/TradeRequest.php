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
            // Entry berlapis. `entry_price` dan `lot` di atas tetap dikirim form
            // sebagai pratinjau, tapi nilai simpannya diturunkan ulang di model.
            'entries' => ['nullable', 'array', 'max:20'],
            'entries.*.price' => ['required', 'numeric', 'gt:0'],
            'entries.*.lot' => ['required', 'numeric', 'gt:0', 'max:10000'],
            'sl_price' => ['nullable', 'numeric', 'gt:0'],
            'tp_price' => ['nullable', 'numeric', 'gt:0'],
            'exit_price' => ['nullable', 'numeric', 'gt:0'],
            'pnl' => ['nullable', 'required_with:closed_at', 'numeric'],
            'closed_at' => ['nullable', 'required_with:pnl', 'date', 'after_or_equal:opened_at'],
            'opened_at' => ['required', 'date'],
            'setup' => ['nullable', 'string', 'max:255'],
            'tags' => ['nullable', 'array', 'max:10'],
            'tags.*' => ['string', 'max:30'],
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
