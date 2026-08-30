<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>Bukti transfer</title>
    <style>
        html, body { height: 100%; margin: 0; background: #0F1420; }
        body { display: flex; align-items: center; justify-content: center; padding: 12px; box-sizing: border-box; }

        /* Penghalang klik kanan, seret keluar, dan tekan-lama di ponsel. Semuanya
           kosmetik — lihat catatan di TransactionController::proofView(). */
        img {
            max-width: 100%;
            max-height: 100%;
            object-fit: contain;
            user-select: none;
            -webkit-user-select: none;
            -webkit-user-drag: none;
            -webkit-touch-callout: none;
        }
    </style>
</head>
<body>
    {{-- Gambarnya tertanam sebagai data URI: tidak ada alamat berkas terpisah
         yang bisa dibuka, disalin, atau dibagikan lepas dari halaman ini. --}}
    <img src="{{ $image }}" alt="Bukti transfer" draggable="false">

    <script>
        for (const event of ['contextmenu', 'dragstart']) {
            addEventListener(event, (e) => e.preventDefault());
        }
    </script>
</body>
</html>
