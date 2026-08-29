@php
    use Carbon\CarbonImmutable;

    // dompdf hanya paham CSS 2.1 — tidak ada flexbox, tidak ada grid, dan Tailwind
    // tidak ikut ke sini. Semua tata letak memakai tabel, semua angka diformat di
    // sini supaya view-nya tidak menghitung apa pun.
    $n = fn (?float $v, int $d = 2) => $v === null ? '—' : number_format($v, $d, ',', '.');
    // Tanda minus di depan simbol mata uang, bukan di antaranya: "-Rp1.000", bukan "Rp-1.000".
    $rp = fn (?float $v) => $v === null ? '—' : ($v < 0 ? '-' : '').'Rp'.number_format(abs($v), 0, ',', '.');
    // Harga instrumen disimpan `decimal(18,5)` sehingga selalu kembali dengan nol di
    // ekornya (4.523,13000). Nol itu tidak membawa informasi — dibuang sampai tersisa
    // dua desimal, sama seperti `price()` di useFormat.ts.
    $harga = function (?float $v) {
        if ($v === null) {
            return '—';
        }

        $s = rtrim(number_format($v, 5, ',', '.'), '0');

        return strlen($s) - strpos($s, ',') > 2 ? $s : number_format($v, 2, ',', '.');
    };
    $cur = fn (?float $v, string $c) => $v === null ? '—' : number_format($v, $c === 'IDR' ? 0 : 2, ',', '.').' '.$c;
    // Kurs selalu dua desimal: `$rp()` membulatkan ke rupiah penuh, dan kurs 17.757,40
    // yang tercetak jadi "Rp17.757" tidak lagi cocok dengan angka yang dipakai menghitung.
    $kurs = fn (?float $v) => $v === null ? '—' : 'Rp'.number_format($v, 2, ',', '.');
    $sign = fn (?float $v) => $v === null ? '' : ($v > 0 ? 'pos' : ($v < 0 ? 'neg' : ''));
    $tgl = fn (?string $d) => $d === null ? '—' : CarbonImmutable::parse($d)->translatedFormat('j M Y');
    $arah = fn (string $d) => $d === 'buy' ? 'Beli' : 'Jual';
    $hasil = fn (string $s) => ['win' => 'Untung', 'loss' => 'Rugi', 'be' => 'Impas'][$s] ?? $s;

    $year = $report['year'];
    $total = $report['total'];
@endphp
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <title>Laporan Tahunan Hasil Trading {{ $year }}</title>
    <style>
        @page { margin: 15mm 8mm 12mm 8mm; }

        /* Helvetica: font inti PDF — tidak ditanam ke berkas, metrikanya lebih ramping
           dari DejaVu, dan bentuknya netral seperti dokumen resmi pada umumnya. */
        body {
            font-family: Helvetica, Arial, sans-serif;
            font-size: 7.5pt;
            color: #111;
            line-height: 1.25;
        }

        #header, #footer {
            position: fixed;
            left: 0;
            right: 0;
            color: #555;
            font-size: 6.5pt;
        }
        #header { top: -10mm; border-bottom: 0.5pt solid #bbb; padding-bottom: 2mm; }
        #footer { bottom: -8mm; border-top: 0.5pt solid #bbb; padding-top: 2mm; }
        #header td, #footer td { border: none; padding: 0; }
        .right { text-align: right; }
        .center { text-align: center; }

        h1 { font-size: 13pt; margin: 0 0 1mm; }
        h2 { font-size: 10pt; margin: 4.5mm 0 1.5mm; border-bottom: 1pt solid #333; padding-bottom: 1mm; }
        h3 { font-size: 8.5pt; margin: 3mm 0 1mm; color: #333; }
        p { margin: 0 0 1.5mm; }

        table { width: 100%; border-collapse: collapse; }
        th, td { border: 0.5pt solid #999; padding: 0.8mm 1.1mm; vertical-align: top; }
        thead { display: table-header-group; }
        th { background: #e8e8e8; font-weight: bold; text-align: left; }
        tr { page-break-inside: avoid; }
        td.num, th.num { text-align: right; }
        td.nowrap { white-space: nowrap; }
        a { color: #14477d; }
        tbody tr.total td { background: #f0f0f0; font-weight: bold; }

        .plain, .plain td { border: none; padding: 0.4mm 0; }
        .pos { color: #14663a; }
        .neg { color: #a01b1b; }
        .muted { color: #666; }
        .note { font-size: 6.5pt; color: #555; margin-top: 1.5mm; }
        .break { page-break-before: always; }
        /* dompdf mengulang <thead> saat tabel terbelah, kecuali kalau baris badan
           pertamanya sudah tidak muat di halaman yang sama — barisnya lalu lahir tanpa
           kepala. Tabel pendek karena itu dipindah utuh ke halaman berikutnya. */
        .keep { page-break-inside: avoid; }
        h3 { page-break-after: avoid; }

        .headline { border: 1pt solid #333; padding: 2.2mm; margin: 2.5mm 0; }
        .headline .label { font-size: 7pt; color: #444; }
        .headline .value { font-size: 14pt; font-weight: bold; }

        .warn { border: 1pt solid #a01b1b; color: #a01b1b; padding: 1.5mm; margin: 1.5mm 0; }
    </style>
</head>
<body>

<div id="header">
    <table class="plain"><tr>
        <td>Laporan Tahunan Hasil Transaksi Perdagangan Berjangka (Trading) — Tahun Pajak {{ $year }}</td>
        <td class="right">{{ $identity['name'] }}@if ($identity['npwp']) — NPWP {{ $identity['npwp'] }}@endif</td>
    </tr></table>
</div>

<div id="footer">
    {{-- Nomor halaman tidak di sini: jumlah halaman baru diketahui setelah seluruh
         dokumen tersusun, jadi ditulis ReportController lewat API kanvas dompdf. --}}
    Dihasilkan otomatis dari basis data jurnal trading pribadi pada {{ $printedAt->translatedFormat('j F Y, H:i') }} WITA.
</div>

{{-- ---------------------------------------------------------------- halaman 1 --}}

<h1>Laporan Tahunan Hasil Transaksi Perdagangan Berjangka (Trading)</h1>
<p><strong>Tahun Pajak {{ $year }}</strong> — periode 1 Januari s.d. 31 Desember {{ $year }}</p>

<h2>Identitas Wajib Pajak</h2>
<table>
    <tr>
        <th style="width: 18%">Nama</th>
        <td style="width: 32%">{{ $identity['name'] }}</td>
        <th style="width: 18%">NPWP</th>
        <td>{{ $identity['npwp'] ?: '—' }}</td>
    </tr>
    <tr>
        <th>Alamat</th>
        <td colspan="3">{{ $identity['address'] ?: '—' }}</td>
    </tr>
    <tr>
        <th>Kurs yang dipakai</th>
        <td>{{ $kurs($report['rate']) }} per 1 USD &middot; kurs tanggal {{ $tgl($report['rate_date']) }}</td>
        <th>Jumlah akun dilaporkan</th>
        <td>{{ count($report['accounts']) }} akun, {{ $n((float) $total['total_trades'], 0) }} transaksi trade</td>
    </tr>
</table>

<h2>Ringkasan Konsolidasi Seluruh Akun (dalam Rupiah)</h2>
<table>
    <thead>
        <tr>
            <th style="width: 16%">Akun</th>
            <th style="width: 14%">Broker</th>
            <th style="width: 6%">Mata Uang</th>
            <th class="num">Saldo Awal</th>
            <th class="num">Setoran</th>
            <th class="num">Penarikan</th>
            <th class="num">Laba/Rugi Bersih</th>
            <th class="num">Saldo Akhir</th>
        </tr>
    </thead>
    <tbody>
        @foreach ($report['accounts'] as $a)
            <tr>
                <td>{{ $a['name'] }}@if ($a['is_archived'])<span class="muted"> (diarsipkan)</span>@endif</td>
                <td>{{ $a['broker'] ?: '—' }}</td>
                <td>{{ $a['currency'] }}</td>
                <td class="num">{{ $rp($a['opening_balance_idr']) }}</td>
                <td class="num">{{ $rp($a['deposit_idr']) }}</td>
                <td class="num">{{ $rp($a['withdrawal_idr']) }}</td>
                <td class="num {{ $sign($a['net_pnl_idr']) }}">{{ $rp($a['net_pnl_idr']) }}</td>
                <td class="num">{{ $rp($a['closing_balance_idr']) }}</td>
            </tr>
        @endforeach
        <tr class="total">
            <td colspan="3">TOTAL</td>
            <td class="num">{{ $rp($total['opening_balance_idr']) }}</td>
            <td class="num">{{ $rp($total['deposit_idr']) }}</td>
            <td class="num">{{ $rp($total['withdrawal_idr']) }}</td>
            <td class="num {{ $sign($total['net_pnl_idr']) }}">{{ $rp($total['net_pnl_idr']) }}</td>
            <td class="num">{{ $rp($total['closing_balance_idr']) }}</td>
        </tr>
    </tbody>
</table>

<table class="plain" style="margin-top: 3mm"><tr>
    <td style="width: 49%">
        <div class="headline">
            <div class="label">Laba/rugi bersih dari trading tahun {{ $year }}</div>
            <div class="value {{ $sign($total['net_pnl_idr']) }}">{{ $rp($total['net_pnl_idr']) }}</div>
            <div class="label">Selisih hasil seluruh transaksi yang sudah ditutup sepanjang tahun.</div>
        </div>
    </td>
    <td style="width: 2%"></td>
    <td style="width: 49%">
        <div class="headline">
            <div class="label">Realisasi kas: penarikan dikurangi setoran</div>
            <div class="value {{ $sign($total['net_cash_idr']) }}">{{ $rp($total['net_cash_idr']) }}</div>
            <div class="label">Uang yang benar-benar keluar-masuk rekening bank sepanjang tahun.</div>
        </div>
    </td>
</tr></table>

<p class="note">
    <strong>Catatan angka.</strong>
    (1) Laba/rugi bersih adalah hasil transaksi yang sudah ditutup; sebagiannya masih
    mengendap sebagai saldo di akun broker dan belum tentu sudah ditarik ke rekening bank.
    Karena itu kedua angka di atas ditampilkan berdampingan.
    (2) Setoran dan penarikan dikonversi memakai kurs yang tercatat pada hari transaksinya
    masing-masing — angka yang sama dengan bukti transfernya. Laba/rugi trading tidak punya
    kurs per transaksi, sehingga dikonversi memakai satu kurs tunggal
    {{ $kurs($report['rate']) }} per USD yang berlaku pada
    {{ CarbonImmutable::parse($report['rate_date'])->translatedFormat('j F Y') }}.
    (3) Saldo awal akun pada tahun pertamanya adalah modal awal yang tercatat saat akun
    dibuat, dan karena itu tidak muncul sebagai baris setoran.
</p>

{{-- ------------------------------------------------------------ rincian per akun --}}

@foreach ($report['accounts'] as $a)
    @php $c = $a['currency']; $s = $a['summary']; @endphp

    <h2 class="break">Rincian Akun: {{ $a['name'] }}@if ($a['is_archived']) (diarsipkan)@endif</h2>

    <table class="keep">
        <tr>
            <th style="width: 12%">Broker</th>
            <td style="width: 21%">{{ $a['broker'] ?: '—' }}</td>
            <th style="width: 12%">Mata uang</th>
            <td style="width: 21%">{{ $c }}</td>
            <th style="width: 12%">Akun dibuka</th>
            <td>{{ $tgl($a['started_at']) }}</td>
        </tr>
    </table>

    <h3>Rekonsiliasi Saldo Tahun {{ $year }}</h3>
    <table class="keep">
        <thead>
            <tr>
                <th>Komponen</th>
                <th class="num" style="width: 22%">{{ $c }}</th>
                <th class="num" style="width: 22%">Rupiah</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td>Saldo awal per 31 Desember {{ $year - 1 }}</td>
                <td class="num">{{ $cur($a['opening_balance'], $c) }}</td>
                <td class="num">{{ $rp($a['opening_balance_idr']) }}</td>
            </tr>
            <tr>
                <td>(+) Setoran modal sepanjang tahun</td>
                <td class="num">{{ $cur($a['deposit'], $c) }}</td>
                <td class="num">{{ $rp($a['deposit_idr']) }}</td>
            </tr>
            <tr>
                <td>(-) Penarikan dana sepanjang tahun</td>
                <td class="num">{{ $cur($a['withdrawal'], $c) }}</td>
                <td class="num">{{ $rp($a['withdrawal_idr']) }}</td>
            </tr>
            <tr>
                <td>(+) Laba/rugi bersih hasil trading</td>
                <td class="num {{ $sign($a['net_pnl']) }}">{{ $cur($a['net_pnl'], $c) }}</td>
                <td class="num {{ $sign($a['net_pnl_idr']) }}">{{ $rp($a['net_pnl_idr']) }}</td>
            </tr>
            <tr class="total">
                <td>(=) Saldo akhir per 31 Desember {{ $year }}</td>
                <td class="num">{{ $cur($a['closing_balance'], $c) }}</td>
                <td class="num">{{ $rp($a['closing_balance_idr']) }}</td>
            </tr>
        </tbody>
    </table>

    @if ($a['reconciliation_gap'] != 0.0)
        <div class="warn">
            Selisih rekonsiliasi {{ $cur($a['reconciliation_gap'], $c) }} — periksa kembali
            catatan akun ini sebelum laporan diserahkan.
        </div>
    @endif

    <h3>Ringkasan Kinerja Tahun {{ $year }}</h3>
    <table class="keep">
        <tr>
            <th style="width: 17%">Jumlah transaksi</th>
            <td class="num" style="width: 16%">{{ $n((float) $s['total_trades'], 0) }}</td>
            <th style="width: 17%">Laba kotor</th>
            <td class="num pos" style="width: 16%">{{ $cur($s['gross_profit'], $c) }}</td>
            <th style="width: 17%">Rugi terbesar</th>
            <td class="num neg">{{ $cur($s['largest_loss'], $c) }}</td>
        </tr>
        <tr>
            <th>Untung / Rugi / Impas</th>
            <td class="num">{{ $s['wins'] }} / {{ $s['losses'] }} / {{ $s['breakeven'] }}</td>
            <th>Rugi kotor</th>
            <td class="num neg">{{ $cur(-$s['gross_loss'], $c) }}</td>
            <th>Untung terbesar</th>
            <td class="num pos">{{ $cur($s['largest_win'], $c) }}</td>
        </tr>
        <tr>
            <th>Tingkat keberhasilan</th>
            <td class="num">{{ $n($s['win_rate_pct'], 1) }}%</td>
            <th>Laba/rugi bersih</th>
            <td class="num {{ $sign($s['net_pnl']) }}">{{ $cur($s['net_pnl'], $c) }}</td>
            <th>Rata-rata per transaksi</th>
            <td class="num {{ $sign($s['expectancy']) }}">{{ $cur($s['expectancy'], $c) }}</td>
        </tr>
        <tr>
            <th>Faktor profit</th>
            <td class="num">{{ $n($s['profit_factor']) }}</td>
            <th>Rentetan untung / rugi</th>
            <td class="num">{{ $s['longest_win_streak'] }} / {{ $s['longest_loss_streak'] }}</td>
            <th>Penurunan saldo terdalam</th>
            <td class="num">{{ $cur($s['max_drawdown']['amount'], $c) }} <span class="muted">(sepanjang riwayat akun)</span></td>
        </tr>
    </table>

    <h3>Rekap Bulanan Tahun {{ $year }}</h3>
    <table class="keep">
        <thead>
            <tr>
                <th>Bulan</th>
                <th class="num">Laba Kotor ({{ $c }})</th>
                <th class="num">Rugi Kotor ({{ $c }})</th>
                <th class="num">Laba/Rugi Bersih ({{ $c }})</th>
                <th class="num">Laba/Rugi Bersih (Rp)</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($a['monthly'] as $m)
                <tr>
                    <td>{{ CarbonImmutable::parse($m['month'].'-01')->translatedFormat('F Y') }}</td>
                    <td class="num">{{ $cur($m['profit'], $c) }}</td>
                    <td class="num">{{ $cur($m['loss'], $c) }}</td>
                    <td class="num {{ $sign($m['pnl']) }}">{{ $cur($m['pnl'], $c) }}</td>
                    <td class="num {{ $sign($m['pnl_idr']) }}">{{ $rp($m['pnl_idr']) }}</td>
                </tr>
            @endforeach
            <tr class="total">
                <td>Jumlah setahun</td>
                <td class="num">{{ $cur($s['gross_profit'], $c) }}</td>
                <td class="num">{{ $cur(-$s['gross_loss'], $c) }}</td>
                <td class="num {{ $sign($s['net_pnl']) }}">{{ $cur($s['net_pnl'], $c) }}</td>
                <td class="num {{ $sign($a['net_pnl_idr']) }}">{{ $rp($a['net_pnl_idr']) }}</td>
            </tr>
        </tbody>
    </table>

    <h3>Mutasi Dana (Setoran &amp; Penarikan)</h3>
    @if ($a['mutations'])
        <table class="keep">
            <thead>
                <tr>
                    <th style="width: 12%">Tanggal</th>
                    <th style="width: 10%">Jenis</th>
                    <th class="num" style="width: 14%">Jumlah ({{ $c }})</th>
                    <th class="num" style="width: 12%">Kurs (Rp/USD)</th>
                    <th class="num" style="width: 15%">Jumlah (Rp)</th>
                    <th style="width: 10%">Bukti</th>
                    <th>Catatan</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($a['mutations'] as $m)
                    <tr>
                        <td>{{ $tgl($m['occurred_at']) }}</td>
                        <td>{{ $m['type'] === 'deposit' ? 'Setoran' : 'Penarikan' }}</td>
                        <td class="num">{{ $cur($m['amount'], $c) }}</td>
                        <td class="num">
                            {{ $kurs($m['rate_idr'] ?? $report['rate']) }}
                            @if ($m['rate_idr'] === null)<span class="muted">*</span>@endif
                        </td>
                        <td class="num">{{ $rp($m['amount_idr']) }}</td>
                        <td>
                            @if ($m['proof_url'])
                                <a href="{{ $m['proof_url'] }}">Lihat bukti</a>
                            @else
                                <span class="muted">Tidak ada</span>
                            @endif
                        </td>
                        <td>{{ $m['note'] ?: '—' }}</td>
                    </tr>
                @endforeach
                <tr class="total">
                    <td colspan="2">Setoran {{ $cur($a['deposit'], $c) }} — Penarikan {{ $cur($a['withdrawal'], $c) }}</td>
                    <td class="num">{{ $cur($a['deposit'] - $a['withdrawal'], $c) }}</td>
                    <td></td>
                    <td class="num">{{ $rp($a['deposit_idr'] - $a['withdrawal_idr']) }}</td>
                    <td colspan="2"></td>
                </tr>
            </tbody>
        </table>
        <p class="note">
            Tautan "Lihat bukti" membuka berkas bukti transfer baris tersebut langsung
            dari aplikasi; perlu masuk sebagai pemilik akun, jadi hanya berfungsi di
            perangkat yang sudah login. Berkasnya dapat dicetak terpisah bila diminta.
            Tanda <span class="muted">*</span> berarti kurs harian baris itu tidak tercatat
            sehingga dipakai kurs tahunan.
        </p>
    @else
        <p class="muted">Tidak ada setoran maupun penarikan pada tahun {{ $year }}.</p>
    @endif

    @if ($a['by_symbol'])
        <h3>Rincian per Instrumen</h3>
        <table class="keep">
            <thead>
                <tr>
                    <th>Instrumen</th>
                    <th class="num" style="width: 12%">Transaksi</th>
                    <th class="num" style="width: 14%">Keberhasilan</th>
                    <th class="num" style="width: 18%">Laba/Rugi ({{ $c }})</th>
                    <th class="num" style="width: 18%">Laba/Rugi (Rp)</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($a['by_symbol'] as $symbol => $row)
                    <tr>
                        <td>{{ $symbol }}</td>
                        <td class="num">{{ $row['trades'] }}</td>
                        <td class="num">{{ $n($row['win_rate_pct'], 1) }}%</td>
                        <td class="num {{ $sign($row['pnl']) }}">{{ $cur($row['pnl'], $c) }}</td>
                        <td class="num {{ $sign($row['pnl_idr']) }}">{{ $rp($row['pnl_idr']) }}</td>
                    </tr>
                @endforeach
                @foreach ($a['by_direction'] as $dir => $row)
                    <tr>
                        <td>Arah: {{ $arah($dir) }}</td>
                        <td class="num">{{ $row['trades'] }}</td>
                        <td class="num">{{ $n($row['win_rate_pct'], 1) }}%</td>
                        <td class="num {{ $sign($row['pnl']) }}">{{ $cur($row['pnl'], $c) }}</td>
                        <td class="num {{ $sign($row['pnl_idr']) }}">{{ $rp($row['pnl_idr']) }}</td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    @endif

    {{-- ----------------------------------------------------------- lampiran akun --}}

    <h2 class="break">Lampiran — Seluruh Transaksi Trade Akun {{ $a['name'] }} Tahun {{ $year }}</h2>
    @if ($a['trades'])
        <table>
            <thead>
                <tr>
                    <th class="num" style="width: 3%">No</th>
                    <th style="width: 12%">Waktu Buka</th>
                    <th style="width: 12%">Waktu Tutup</th>
                    <th style="width: 7%">Instrumen</th>
                    <th style="width: 5%">Arah</th>
                    <th class="num" style="width: 5%">Lot</th>
                    <th class="num" style="width: 7%">Harga Masuk</th>
                    <th class="num" style="width: 7%">Harga Keluar</th>
                    <th class="num" style="width: 7%">Stop Loss</th>
                    <th class="num" style="width: 7%">Take Profit</th>
                    <th class="num" style="width: 10%">Laba/Rugi ({{ $c }})</th>
                    <th class="num" style="width: 11%">Laba/Rugi (Rp)</th>
                    <th style="width: 6%">Hasil</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($a['trades'] as $i => $t)
                    <tr>
                        <td class="num">{{ $i + 1 }}</td>
                        <td class="nowrap">{{ $t['opened_at'] }}</td>
                        <td class="nowrap">{{ $t['closed_at'] ?: '—' }}</td>
                        <td>{{ $t['symbol'] }}</td>
                        <td>{{ $arah($t['direction']) }}</td>
                        <td class="num">{{ $n($t['lot']) }}</td>
                        <td class="num">{{ $harga($t['entry_price']) }}</td>
                        <td class="num">{{ $harga($t['exit_price']) }}</td>
                        <td class="num">{{ $harga($t['sl_price']) }}</td>
                        <td class="num">{{ $harga($t['tp_price']) }}</td>
                        {{-- Satuannya sudah ada di kepala kolom; mengulangnya tiap baris
                             membuat kolomnya melipat dan lampiran jadi dua kali lebih tebal. --}}
                        <td class="num {{ $sign($t['pnl']) }}">{{ $n($t['pnl']) }}</td>
                        <td class="num {{ $sign($t['pnl_idr']) }}">{{ $rp($t['pnl_idr']) }}</td>
                        <td>{{ $hasil($t['status']) }}</td>
                    </tr>
                @endforeach
                <tr class="total">
                    <td colspan="10">Jumlah {{ count($a['trades']) }} transaksi</td>
                    <td class="num {{ $sign($a['net_pnl']) }}">{{ $n($a['net_pnl']) }}</td>
                    <td class="num {{ $sign($a['net_pnl_idr']) }}">{{ $rp($a['net_pnl_idr']) }}</td>
                    <td></td>
                </tr>
            </tbody>
        </table>
    @else
        <p class="muted">Tidak ada transaksi trade yang ditutup pada tahun {{ $year }}.</p>
    @endif
@endforeach

{{-- ------------------------------------------------------------------- penutup --}}

<h2 class="break">Pernyataan</h2>
<p>
    Data dalam laporan ini bersumber dari catatan jurnal trading pribadi yang saya
    rekam sendiri pada saat atau segera setelah setiap transaksi terjadi. Seluruh
    angka ringkasan dihitung langsung dari catatan tersebut dan dapat ditelusuri ke
    baris transaksinya pada bagian Lampiran.
</p>
<p>
    Setiap setoran dan penarikan dana disertai bukti transfer yang tersimpan dan dapat
    ditunjukkan apabila diperlukan. Laba/rugi trading dikonversi ke rupiah memakai satu
    kurs sebesar {{ $kurs($report['rate']) }} per USD yang berlaku pada
    {{ CarbonImmutable::parse($report['rate_date'])->translatedFormat('j F Y') }},
    sementara setoran dan penarikan memakai kurs yang berlaku pada hari transaksinya
    masing-masing.
</p>
<p>
    Demikian laporan ini saya buat dengan sebenarnya. Apabila di kemudian hari terdapat
    data yang perlu diperbaiki, saya bersedia melakukan pembetulan.
</p>

<table class="plain" style="margin-top: 10mm">
    <tr>
        <td style="width: 65%"></td>
        <td class="center">
            <div>{{ $printedAt->translatedFormat('j F Y') }}</div>
            <div>Wajib Pajak,</div>
            <div style="height: 22mm"></div>
            <div><strong>{{ $identity['name'] }}</strong></div>
            @if ($identity['npwp'])<div>NPWP {{ $identity['npwp'] }}</div>@endif
        </td>
    </tr>
</table>

</body>
</html>
