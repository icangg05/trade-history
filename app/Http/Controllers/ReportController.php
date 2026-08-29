<?php

namespace App\Http\Controllers;

use App\Models\Account;
use App\Services\AnnualReport;
use Carbon\CarbonImmutable;
use Dompdf\Dompdf;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;
use Inertia\Inertia;
use Inertia\Response as InertiaResponse;

class ReportController extends Controller
{
    public function index(Request $request): InertiaResponse
    {
        $accounts = $this->accounts();
        $now = CarbonImmutable::now();

        // Dari tahun akun tertua sampai tahun berjalan. Akun sudah di memori,
        // jadi tidak ada query tambahan untuk daftar ini.
        $oldest = (int) ($accounts->min('started_at')?->year ?: $now->year);

        return Inertia::render('Report', [
            'years' => range($now->year, min($oldest, $now->year)),
            'defaultName' => $request->user()->name,
            'accounts' => $accounts->map->only('id', 'name', 'broker', 'currency', 'is_archived')->values(),
        ]);
    }

    public function pdf(Request $request): Response
    {
        $request->merge(['rate' => self::decimal($request->input('rate'))]);

        $data = $request->validate([
            'year' => ['required', 'integer', 'between:2000,'.CarbonImmutable::now()->year],
            // Kurs laba/rugi trading. Setor/tarik tetap memakai kurs harinya sendiri.
            'rate' => ['required', 'numeric', 'gt:0'],
            // Kurs tanpa tanggal tidak bisa diperiksa ulang oleh petugas pajak, jadi
            // tanggalnya wajib dan ikut tercetak di laporan.
            'rate_date' => ['required', 'date', 'before_or_equal:today'],
            'name' => ['required', 'string', 'max:255'],
            'npwp' => ['nullable', 'string', 'max:32'],
            'address' => ['nullable', 'string', 'max:500'],
        ]);

        $report = AnnualReport::build(
            $this->accounts(),
            (int) $data['year'],
            (float) $data['rate'],
            $data['rate_date'],
        );

        // Helvetica: font inti PDF, jadi tidak ikut ditanam ke berkas — lebih ramping
        // dari DejaVu sehingga tabel lampiran muat lebih banyak baris per halaman.
        $dompdf = new Dompdf(['isRemoteEnabled' => false, 'defaultFont' => 'Helvetica']);
        $dompdf->setPaper('a4', 'landscape');
        $dompdf->loadHtml(view('reports.annual', [
            'report' => $report,
            'identity' => [
                'name' => $data['name'],
                'npwp' => $data['npwp'] ?? null,
                'address' => $data['address'] ?? null,
            ],
            'printedAt' => CarbonImmutable::now(),
        ])->render(), 'UTF-8');
        $dompdf->render();

        // `counter(pages)` di CSS selalu 0: dompdf menghitungnya saat menyusun tata
        // letak, ketika jumlah halaman belum diketahui. `page_text` mengisinya setelah
        // dokumen jadi — lewat API kanvas, bukan <script type="text/php"> yang
        // mengharuskan eksekusi PHP di dalam HTML dinyalakan.
        $canvas = $dompdf->getCanvas();
        $canvas->page_text(
            $canvas->get_width() - 130,
            $canvas->get_height() - 25,
            'Halaman {PAGE_NUM} dari {PAGE_COUNT}',
            $dompdf->getFontMetrics()->getFont('Helvetica'),
            7,
            [0.33, 0.33, 0.33],
        );

        $filename = 'laporan-trading-'.$data['year'].'-'.Str::slug($data['name']).'.pdf';

        return response($dompdf->output(), 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="'.$filename.'"',
        ]);
    }

    /**
     * Kurs boleh ditulis dengan gaya Indonesia (`17.757,40`) maupun gaya mesin
     * (`17757.40`). Koma hanya bisa berarti desimal, jadi begitu ia muncul titik
     * pasti pemisah ribuan. Tanpa koma tidak ada yang bisa disimpulkan, dan
     * angkanya dibiarkan apa adanya — halaman laporan menampilkan hasil bacaannya
     * kembali supaya salah tafsir ketahuan sebelum PDF-nya diunduh.
     */
    private static function decimal(mixed $value): mixed
    {
        return is_string($value) && str_contains($value, ',')
            ? str_replace(['.', ','], ['', '.'], trim($value))
            : $value;
    }

    /**
     * Sengaja tidak lewat `$request->accountList()`: middleware itu membuang akun
     * yang diarsipkan, sedangkan akun arsip bisa menyimpan trade di tahun pajak
     * yang diminta. Menghilangkannya membuat laporan mengecilkan penghasilan.
     *
     * @return Collection<int, Account>
     */
    private function accounts()
    {
        return Account::query()
            ->where('user_id', Auth::id())
            ->orderBy('started_at')
            ->orderBy('name')
            ->get();
    }
}
