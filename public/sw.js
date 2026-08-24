/**
 * Service worker seadanya: cukup untuk membuat aplikasi bisa dipasang dan
 * memuat aset lebih cepat, tanpa risiko menyajikan HTML basi.
 *
 * - Aset build & ikon: cache-first (namanya sudah mengandung hash isi).
 * - Sisanya (semua HTML, semua request Inertia): langsung ke jaringan.
 * - Navigasi saat offline: halaman pemberitahuan singkat.
 */
const CACHE = 'trade-history-v1'
const CACHEABLE = /^\/(build\/|icons\/|favicon\.ico$|manifest\.webmanifest$)/

self.addEventListener('install', () => self.skipWaiting())

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim()),
  )
})

self.addEventListener('fetch', (event) => {
  const { request } = event
  const url = new URL(request.url)

  if (request.method !== 'GET' || url.origin !== self.location.origin) return

  if (CACHEABLE.test(url.pathname)) {
    event.respondWith(
      caches.match(request).then(
        (hit) =>
          hit ??
          fetch(request).then((response) => {
            if (response.ok) {
              const copy = response.clone()
              caches.open(CACHE).then((cache) => cache.put(request, copy))
            }

            return response
          }),
      ),
    )

    return
  }

  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(() => offlinePage()))
  }
})

function offlinePage() {
  return new Response(
    `<!doctype html><html lang="id"><head><meta charset="utf-8">
     <meta name="viewport" content="width=device-width,initial-scale=1">
     <title>Offline</title>
     <style>
       body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0b0d14;
            color:#e8edf3;font-family:'IBM Plex Sans',system-ui,sans-serif;text-align:center;padding:2rem}
       h1{font-size:1.05rem;margin:0 0 .5rem}
       p{font-size:.85rem;color:#8d97a8;margin:0 0 1.25rem}
       button{background:#fbbd23;color:#141002;border:0;border-radius:.5rem;
              padding:.55rem 1.1rem;font:inherit;font-weight:600;cursor:pointer}
     </style></head>
     <body><div><h1>Tidak ada koneksi</h1>
     <p>Trade History butuh internet untuk memuat data akun.</p>
     <button onclick="location.reload()">Coba lagi</button></div></body></html>`,
    { status: 503, headers: { 'Content-Type': 'text/html; charset=utf-8' } },
  )
}
