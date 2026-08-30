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
        @page { margin: 16mm 8mm 13mm 8mm; }

        /* Warna diambil dari tema aplikasi (resources/css/app.css), digelapkan
           seperlunya supaya tetap terbaca di atas kertas putih. */
        /* Helvetica: font inti PDF, jadi tidak ikut ditanam ke berkas dan bentuknya
           sama dengan yang dipakai lembar rekening koran pada umumnya. */
        body {
            font-family: Helvetica, Arial, sans-serif;
            font-size: 7.5pt;
            color: #151B28;
            line-height: 1.25;
            /* Watermark diulang sebagai latar tiap halaman. Harus menempel di `body`:
               dompdf mengabaikan latar pada `html`. Sel data sengaja dibiarkan tembus
               supaya polanya utuh; hanya kepala tabel yang menutupinya. */
            background-image: url('{{ $brand['watermark'] }}');
            background-repeat: repeat;
        }

        #header, #footer { position: fixed; left: 0; right: 0; font-size: 6.5pt; color: #5A6679; }
        #header { top: -13mm; border-bottom: 0.5pt solid #C9CFDA; padding-bottom: 1.5mm; }
        #footer { bottom: -9mm; border-top: 0.5pt solid #C9CFDA; padding-top: 1.5mm; }
        #header td, #footer td { border: none; padding: 0; }
        .right { text-align: right; }
        .center { text-align: center; }

        /* Kop halaman pertama */
        .masthead td { border: none; padding: 0; vertical-align: middle; }
        .masthead .logo { width: 15mm; }
        .masthead .logo img { width: 13mm; height: 13mm; }
        .brand { font-size: 12pt; font-weight: bold; letter-spacing: 0.4pt; }
        .brand-sub { font-size: 6.5pt; color: #5A6679; }
        .doctitle { font-size: 11.5pt; font-weight: bold; }
        .rule { border-bottom: 2pt solid #E9AA0C; margin: 2mm 0 3mm; }

        h2 {
            font-size: 9.5pt;
            margin: 4.5mm 0 1.5mm;
            padding: 1mm 0 1mm 2mm;
            border-left: 2.5pt solid #E9AA0C;
            background: #F4F6F9;
        }
        h3 { font-size: 8.5pt; margin: 3mm 0 1mm; page-break-after: avoid; }
        p { margin: 0 0 1.5mm; }

        /* Terjemahan Inggris di bawah label Indonesia, seperti lembar resmi bank. */
        .en { display: block; font-style: italic; font-weight: normal; color: #7A8698; font-size: 6pt; }

        table { width: 100%; border-collapse: collapse; }
        th, td { border: 0.5pt solid #C9CFDA; padding: 0.8mm 1.1mm; vertical-align: top; }
        thead { display: table-header-group; }
        th { background: #FEF3D7; font-weight: bold; text-align: left; }
        tr { page-break-inside: avoid; }
        td.num, th.num { text-align: right; }
        td.nowrap { white-space: nowrap; }
        a { color: #1B5FA8; }
        tbody tr.total td { background: #F4F6F9; font-weight: bold; }
        .keep { page-break-inside: avoid; }

        .plain, .plain td { border: none; padding: 0.4mm 0; background: transparent; }
        .pos { color: #18774B; }
        .neg { color: #BA1C1C; }
        .muted { color: #7A8698; }
        .note { font-size: 6.5pt; color: #4A5566; margin-top: 1.5mm; }
        .break { page-break-before: always; }

        .headline { border: 0.5pt solid #C9CFDA; border-top: 2pt solid #E9AA0C; padding: 2.2mm; }
        .headline .label { font-size: 7pt; color: #4A5566; }
        .headline .value { font-size: 14pt; font-weight: bold; }

        .warn { border: 1pt solid #BA1C1C; color: #BA1C1C; padding: 1.5mm; margin: 1.5mm 0; }

        /* Catatan penutup: butir Indonesia dengan terjemahan miring di bawahnya. */
        .terms { margin-top: 2mm; }
        .terms td { border: none; padding: 0.6mm 0 1.6mm; background: transparent; }
        .terms .id { font-size: 7pt; }
        .terms .en { font-size: 6.2pt; }
    </style>
</head>
<body>

<div id="header">
    <table class="plain"><tr>
        <td>Laporan Tahunan Hasil Trading Tahun Pajak {{ $year }}</td>
        <td class="right">{{ $identity['name'] }}@if ($identity['npwp']), NPWP {{ $identity['npwp'] }}@endif</td>
    </tr></table>
</div>

<div id="footer">
    {{-- Nomor halaman tidak di sini: jumlah halaman baru diketahui setelah seluruh
         dokumen tersusun, jadi ditulis ReportController lewat API kanvas dompdf. --}}
    Dokumen dihasilkan otomatis dari basis data {{ $brand['name'] }} pada {{ $printedAt->translatedFormat('j F Y, H:i') }} WITA.
</div>

{{-- ---------------------------------------------------------------- halaman 1 --}}

<table class="masthead">
    <tr>
        <td class="logo"><img src="{{ $brand['logo'] }}" alt=""></td>
        <td>
            <div class="brand">{{ mb_strtoupper($brand['name']) }}</div>
            <div class="brand-sub">Jurnal trading pribadi <span style="font-style: italic">/ Personal trading journal</span></div>
        </td>
        <td class="right">
            <div class="doctitle">LAPORAN TAHUNAN HASIL TRADING</div>
            <div class="brand-sub" style="font-style: italic">ANNUAL TRADING RESULT REPORT</div>
        </td>
    </tr>
</table>
<div class="rule"></div>

<table class="plain"><tr>
    <td><strong>Tahun Pajak {{ $year }}</strong> <span class="muted">/ Tax Year {{ $year }}</span></td>
    <td class="right">Periode 1 Januari s.d. 31 Desember {{ $year }} <span class="muted">/ Period</span></td>
</tr></table>

<h2>Identitas Wajib Pajak<span class="en">Taxpayer Identity</span></h2>
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
        <td>{{ $kurs($report['rate']) }} per 1 USD, kurs tanggal {{ $tgl($report['rate_date']) }}</td>
        <th>Jumlah akun dilaporkan</th>
        <td>{{ count($report['accounts']) }} akun, {{ $n((float) $total['total_trades'], 0) }} transaksi trade</td>
    </tr>
</table>

<h2>Ringkasan Konsolidasi Seluruh Akun (dalam Rupiah)<span class="en">Consolidated Summary of All Accounts (in Rupiah)</span></h2>
<table>
    <thead>
        <tr>
            <th style="width: 16%">Akun<span class="en">Account</span></th>
            <th style="width: 12%">Broker<span class="en">Broker</span></th>
            <th style="width: 10%">Nomor Akun<span class="en">Account No.</span></th>
            <th style="width: 6%">Mata Uang<span class="en">Currency</span></th>
            <th class="num">Saldo Awal<span class="en">Opening Balance</span></th>
            <th class="num">Setoran<span class="en">Deposits</span></th>
            <th class="num">Penarikan<span class="en">Withdrawals</span></th>
            <th class="num">Laba/Rugi Bersih<span class="en">Net Profit/Loss</span></th>
            <th class="num">Saldo Akhir<span class="en">Closing Balance</span></th>
        </tr>
    </thead>
    <tbody>
        @foreach ($report['accounts'] as $a)
            <tr>
                <td>{{ $a['name'] }}@if ($a['is_archived'])<span class="muted"> (diarsipkan)</span>@endif</td>
                <td>{{ $a['broker'] ?: '—' }}</td>
                <td>{{ $a['account_number'] ?: '—' }}</td>
                <td>{{ $a['currency'] }}</td>
                <td class="num">{{ $rp($a['opening_balance_idr']) }}</td>
                <td class="num">{{ $rp($a['deposit_idr']) }}</td>
                <td class="num">{{ $rp($a['withdrawal_idr']) }}</td>
                <td class="num {{ $sign($a['net_pnl_idr']) }}">{{ $rp($a['net_pnl_idr']) }}</td>
                <td class="num">{{ $rp($a['closing_balance_idr']) }}</td>
            </tr>
        @endforeach
        <tr class="total">
            <td colspan="4">TOTAL</td>
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

<table class="terms">
    <tr><td>
        <div class="id">1. Laba/rugi bersih adalah hasil seluruh transaksi yang sudah ditutup. Sebagiannya masih
            mengendap sebagai saldo di akun broker dan belum ditarik ke rekening bank, sehingga kedua
            angka di atas ditampilkan berdampingan.</div>
        <div class="en">Net profit/loss covers all closed positions. Part of it still sits as broker account
            balance and has not been withdrawn to a bank account, hence both figures are shown side by side.</div>
    </td></tr>
    <tr><td>
        <div class="id">2. Setoran dan penarikan dikonversi memakai kurs yang tercatat pada hari transaksinya
            masing-masing, yaitu angka yang sama dengan bukti transfernya. Laba/rugi trading tidak punya kurs per
            transaksi sehingga dikonversi memakai satu kurs tunggal {{ $kurs($report['rate']) }} per USD yang berlaku
            pada {{ CarbonImmutable::parse($report['rate_date'])->translatedFormat('j F Y') }}.</div>
        <div class="en">Deposits and withdrawals are converted at the rate recorded on their own transaction date,
            matching the transfer receipts. Trading results carry no per-transaction rate and are therefore converted
            at a single rate as stated above.</div>
    </td></tr>
    <tr><td>
        <div class="id">3. Saldo awal akun pada tahun pertamanya adalah modal awal yang tercatat saat akun dibuat,
            sehingga tidak muncul sebagai baris setoran.</div>
        <div class="en">An account's opening balance in its first year is the initial capital recorded at account
            creation, and therefore does not appear as a deposit entry.</div>
    </td></tr>
</table>

{{-- ------------------------------------------------------------ rincian per akun --}}

@foreach ($report['accounts'] as $a)
    @php
        $c = $a['currency'];
        $s = $a['summary'];
        // Akun rupiah: kolom mata uang akun dan kolom rupiahnya berisi angka yang
        // persis sama. Kolom kedua dibuang, yang tersisa diformat sebagai rupiah.
        $isRp = $c === 'IDR';
        $u = $isRp ? 'Rp' : $c;
        $v = $isRp ? $rp : fn (?float $x) => $cur($x, $c);
    @endphp

    <h2 class="break">Rincian Akun: {{ $a['name'] }}@if ($a['is_archived']) (diarsipkan)@endif<span class="en">Account Detail</span></h2>

    <table class="keep">
        <tr>
            <th style="width: 11%">Broker<span class="en">Broker</span></th>
            <td style="width: 17%">{{ $a['broker'] ?: '—' }}</td>
            <th style="width: 12%">Nomor akun<span class="en">Account number</span></th>
            <td style="width: 17%">{{ $a['account_number'] ?: '—' }}</td>
            <th style="width: 10%">Mata uang<span class="en">Currency</span></th>
            <td style="width: 10%">{{ $c }}</td>
            <th style="width: 11%">Akun dibuka<span class="en">Opened on</span></th>
            <td>{{ $tgl($a['started_at']) }}</td>
        </tr>
    </table>

    <h3>Rekonsiliasi Saldo Tahun {{ $year }} <span class="muted" style="font-style: italic; font-weight: normal">/ Balance Reconciliation</span></h3>
    <table class="keep">
        <thead>
            <tr>
                <th>Komponen</th>
                @unless ($isRp)<th class="num" style="width: 22%">{{ $c }}</th>@endunless
                <th class="num" style="width: 22%">Rupiah</th>
            </tr>
        </thead>
        <tbody>
            <tr>
                <td>Saldo awal per 31 Desember {{ $year - 1 }}</td>
                @unless ($isRp)<td class="num">{{ $cur($a['opening_balance'], $c) }}</td>@endunless
                <td class="num">{{ $rp($a['opening_balance_idr']) }}</td>
            </tr>
            <tr>
                <td>(+) Setoran modal sepanjang tahun</td>
                @unless ($isRp)<td class="num">{{ $cur($a['deposit'], $c) }}</td>@endunless
                <td class="num">{{ $rp($a['deposit_idr']) }}</td>
            </tr>
            <tr>
                <td>(-) Penarikan dana sepanjang tahun</td>
                @unless ($isRp)<td class="num">{{ $cur($a['withdrawal'], $c) }}</td>@endunless
                <td class="num">{{ $rp($a['withdrawal_idr']) }}</td>
            </tr>
            <tr>
                <td>(+) Laba/rugi bersih hasil trading</td>
                @unless ($isRp)<td class="num {{ $sign($a['net_pnl']) }}">{{ $cur($a['net_pnl'], $c) }}</td>@endunless
                <td class="num {{ $sign($a['net_pnl_idr']) }}">{{ $rp($a['net_pnl_idr']) }}</td>
            </tr>
            <tr class="total">
                <td>(=) Saldo akhir per 31 Desember {{ $year }}</td>
                @unless ($isRp)<td class="num">{{ $cur($a['closing_balance'], $c) }}</td>@endunless
                <td class="num">{{ $rp($a['closing_balance_idr']) }}</td>
            </tr>
        </tbody>
    </table>

    @if ($a['reconciliation_gap'] != 0.0)
        <div class="warn">
            Selisih rekonsiliasi {{ $v($a['reconciliation_gap']) }}. Periksa kembali
            catatan akun ini sebelum laporan diserahkan.
        </div>
    @endif

    <h3>Ringkasan Kinerja Tahun {{ $year }} <span class="muted" style="font-style: italic; font-weight: normal">/ Performance Summary</span></h3>
    <table class="keep">
        <tr>
            <th style="width: 17%">Jumlah transaksi</th>
            <td class="num" style="width: 16%">{{ $n((float) $s['total_trades'], 0) }}</td>
            <th style="width: 17%">Laba kotor</th>
            <td class="num pos" style="width: 16%">{{ $v($s['gross_profit']) }}</td>
            <th style="width: 17%">Rugi terbesar</th>
            <td class="num neg">{{ $v($s['largest_loss']) }}</td>
        </tr>
        <tr>
            <th>Untung / Rugi / Impas</th>
            <td class="num">{{ $s['wins'] }} / {{ $s['losses'] }} / {{ $s['breakeven'] }}</td>
            <th>Rugi kotor</th>
            <td class="num neg">{{ $v(-$s['gross_loss']) }}</td>
            <th>Untung terbesar</th>
            <td class="num pos">{{ $v($s['largest_win']) }}</td>
        </tr>
        <tr>
            <th>Tingkat keberhasilan</th>
            <td class="num">{{ $n($s['win_rate_pct'], 1) }}%</td>
            <th>Laba/rugi bersih</th>
            <td class="num {{ $sign($s['net_pnl']) }}">{{ $v($s['net_pnl']) }}</td>
            <th>Rata-rata per transaksi</th>
            <td class="num {{ $sign($s['expectancy']) }}">{{ $v($s['expectancy']) }}</td>
        </tr>
        <tr>
            <th>Faktor profit</th>
            <td class="num">{{ $n($s['profit_factor']) }}</td>
            <th>Rentetan untung / rugi</th>
            <td class="num">{{ $s['longest_win_streak'] }} / {{ $s['longest_loss_streak'] }}</td>
            <th>Penurunan saldo terdalam</th>
            <td class="num">{{ $v($s['max_drawdown']['amount']) }} <span class="muted">(sepanjang riwayat akun, di luar setor/tarik)</span></td>
        </tr>
    </table>

    <h3>Rekap Bulanan Tahun {{ $year }} <span class="muted" style="font-style: italic; font-weight: normal">/ Monthly Recap</span></h3>
    <table class="keep">
        <thead>
            <tr>
                <th>Bulan</th>
                <th class="num">Laba Kotor ({{ $u }})</th>
                <th class="num">Rugi Kotor ({{ $u }})</th>
                <th class="num">Laba/Rugi Bersih ({{ $u }})</th>
                @unless ($isRp)<th class="num">Laba/Rugi Bersih (Rp)</th>@endunless
            </tr>
        </thead>
        <tbody>
            @foreach ($a['monthly'] as $m)
                <tr>
                    <td>{{ CarbonImmutable::parse($m['month'].'-01')->translatedFormat('F Y') }}</td>
                    <td class="num">{{ $v($m['profit']) }}</td>
                    <td class="num">{{ $v($m['loss']) }}</td>
                    <td class="num {{ $sign($m['pnl']) }}">{{ $v($m['pnl']) }}</td>
                    @unless ($isRp)<td class="num {{ $sign($m['pnl_idr']) }}">{{ $rp($m['pnl_idr']) }}</td>@endunless
                </tr>
            @endforeach
            <tr class="total">
                <td>Jumlah setahun</td>
                <td class="num">{{ $v($s['gross_profit']) }}</td>
                <td class="num">{{ $v(-$s['gross_loss']) }}</td>
                <td class="num {{ $sign($s['net_pnl']) }}">{{ $v($s['net_pnl']) }}</td>
                @unless ($isRp)<td class="num {{ $sign($a['net_pnl_idr']) }}">{{ $rp($a['net_pnl_idr']) }}</td>@endunless
            </tr>
        </tbody>
    </table>

    <h3>Mutasi Dana (Setoran &amp; Penarikan) <span class="muted" style="font-style: italic; font-weight: normal">/ Fund Movements</span></h3>
    @if ($a['mutations'])
        <table class="keep">
            <thead>
                <tr>
                    <th style="width: 12%">Tanggal</th>
                    <th style="width: 10%">Jenis</th>
                    @unless ($isRp)
                        <th class="num" style="width: 14%">Jumlah ({{ $c }})</th>
                        <th class="num" style="width: 12%">Kurs (Rp/USD)</th>
                    @endunless
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
                        @unless ($isRp)
                            <td class="num">{{ $cur($m['amount'], $c) }}</td>
                            <td class="num">
                                {{ $kurs($m['rate_idr'] ?? $report['rate']) }}
                                @if ($m['rate_idr'] === null)<span class="muted">*</span>@endif
                            </td>
                        @endunless
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
                    <td colspan="2">Jumlah setoran {{ $v($a['deposit']) }}, penarikan {{ $v($a['withdrawal']) }}</td>
                    @unless ($isRp)
                        <td class="num">{{ $cur($a['deposit'] - $a['withdrawal'], $c) }}</td>
                        <td></td>
                    @endunless
                    <td class="num">{{ $rp($a['deposit_idr'] - $a['withdrawal_idr']) }}</td>
                    <td colspan="2"></td>
                </tr>
            </tbody>
        </table>
        <p class="note">
            Tautan "Lihat bukti" membuka berkas bukti transfer baris tersebut langsung dari
            aplikasi tanpa perlu masuk. Setiap kali diklik, tautan ini memberi akses selama
            15 detik; lewat dari itu alamat yang terbuka kedaluwarsa, dan berkasnya dibuka
            kembali dengan mengklik ulang tautan di dokumen ini. Berkasnya dapat dicetak
            terpisah bila diminta.
            @unless ($isRp)
                Tanda <span class="muted">*</span> berarti kurs harian baris itu tidak tercatat
                sehingga dipakai kurs tahunan.
            @endunless
        </p>
    @else
        <p class="muted">Tidak ada setoran maupun penarikan pada tahun {{ $year }}.</p>
    @endif

    @if ($a['by_symbol'])
        <h3>Rincian per Instrumen <span class="muted" style="font-style: italic; font-weight: normal">/ Breakdown by Instrument</span></h3>
        <table class="keep">
            <thead>
                <tr>
                    <th>Instrumen</th>
                    <th class="num" style="width: 12%">Transaksi</th>
                    <th class="num" style="width: 14%">Keberhasilan</th>
                    @unless ($isRp)<th class="num" style="width: 18%">Laba/Rugi ({{ $c }})</th>@endunless
                    <th class="num" style="width: 18%">Laba/Rugi (Rp)</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($a['by_symbol'] as $symbol => $row)
                    <tr>
                        <td>{{ $symbol }}</td>
                        <td class="num">{{ $row['trades'] }}</td>
                        <td class="num">{{ $n($row['win_rate_pct'], 1) }}%</td>
                        @unless ($isRp)<td class="num {{ $sign($row['pnl']) }}">{{ $cur($row['pnl'], $c) }}</td>@endunless
                        <td class="num {{ $sign($row['pnl_idr']) }}">{{ $rp($row['pnl_idr']) }}</td>
                    </tr>
                @endforeach
                @foreach ($a['by_direction'] as $dir => $row)
                    <tr>
                        <td>Arah: {{ $arah($dir) }}</td>
                        <td class="num">{{ $row['trades'] }}</td>
                        <td class="num">{{ $n($row['win_rate_pct'], 1) }}%</td>
                        @unless ($isRp)<td class="num {{ $sign($row['pnl']) }}">{{ $cur($row['pnl'], $c) }}</td>@endunless
                        <td class="num {{ $sign($row['pnl_idr']) }}">{{ $rp($row['pnl_idr']) }}</td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    @endif

    {{-- ----------------------------------------------------------- lampiran akun --}}

    <h2 class="break">Lampiran: Seluruh Transaksi Trade Akun {{ $a['name'] }} Tahun {{ $year }}<span class="en">Appendix: All Trade Transactions</span></h2>
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
                    @unless ($isRp)<th class="num" style="width: 10%">Laba/Rugi ({{ $c }})</th>@endunless
                    <th class="num" style="width: 11%">Laba/Rugi (Rp)</th>
                    <th style="width: 6%">Hasil</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($a['trades'] as $i => $t)
                    <tr>
                        <td class="num">{{ $i + 1 }}.</td>
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
                        @unless ($isRp)<td class="num {{ $sign($t['pnl']) }}">{{ $n($t['pnl']) }}</td>@endunless
                        <td class="num {{ $sign($t['pnl_idr']) }}">{{ $rp($t['pnl_idr']) }}</td>
                        <td>{{ $hasil($t['status']) }}</td>
                    </tr>
                @endforeach
                <tr class="total">
                    <td colspan="10">Jumlah {{ count($a['trades']) }} transaksi</td>
                    @unless ($isRp)<td class="num {{ $sign($a['net_pnl']) }}">{{ $n($a['net_pnl']) }}</td>@endunless
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

<h2 class="break">Pernyataan<span class="en">Statement</span></h2>

<table class="terms">
    <tr><td>
        <div class="id">1. Data dalam laporan ini bersumber dari catatan jurnal trading pribadi yang saya rekam
            sendiri pada saat atau segera setelah setiap transaksi terjadi. Seluruh angka ringkasan dihitung langsung
            dari catatan tersebut dan dapat ditelusuri ke baris transaksinya pada bagian Lampiran.</div>
        <div class="en">The data in this report comes from a personal trading journal recorded at, or immediately
            after, each transaction. Every summary figure is computed directly from those records and can be traced
            to its underlying entry in the Appendix.</div>
    </td></tr>
    <tr><td>
        <div class="id">2. Setiap setoran dan penarikan dana disertai bukti transfer yang tersimpan dan dapat
            ditunjukkan apabila diperlukan.</div>
        <div class="en">Each deposit and withdrawal is backed by a stored transfer receipt that can be produced on request.</div>
    </td></tr>
    <tr><td>
        <div class="id">3. Laporan ini dihasilkan otomatis oleh aplikasi {{ $brand['name'] }} milik saya sendiri,
            bukan terbitan bank, broker, maupun instansi mana pun. Berkas ini merupakan salinan catatan pribadi yang
            saya sampaikan untuk keperluan klarifikasi.</div>
        <div class="en">This report is generated automatically by the author's own {{ $brand['name'] }} application.
            It is not issued by any bank, broker, or institution, and constitutes a copy of personal records submitted
            for clarification purposes.</div>
    </td></tr>
    <tr><td>
        <div class="id">4. Demikian laporan ini saya buat dengan sebenarnya. Apabila di kemudian hari terdapat data
            yang perlu diperbaiki, saya bersedia melakukan pembetulan.</div>
        <div class="en">This report is made truthfully. Should any data later require correction, the undersigned is
            prepared to submit an amendment.</div>
    </td></tr>
</table>

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
