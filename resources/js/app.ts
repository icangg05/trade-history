import '../css/app.css'

import { createApp, h, type DefineComponent } from 'vue'
import { createInertiaApp } from '@inertiajs/vue3'
import AppLayout from '@/layouts/AppLayout.vue'
import { listenForInstall } from '@/composables/useInstall'

listenForInstall()

const appName = import.meta.env.VITE_APP_NAME || 'Trade History'
// Halaman yang berdiri sendiri tanpa shell aplikasi: dua halaman auth dan
// halaman galat, yang juga bisa muncul untuk pengunjung yang belum masuk.
const BARE_PAGES = new Set(['Login', 'Register', 'Error'])

createInertiaApp({
  title: (title) => (title ? `${title} · ${appName}` : appName),

  resolve: async (name) => {
    const pages = import.meta.glob<DefineComponent>('./pages/**/*.vue')
    const page = await pages[`./pages/${name}.vue`]()

    page.default.layout ??= BARE_PAGES.has(name) ? undefined : AppLayout

    return page
  },

  setup({ el, App, props, plugin }) {
    createApp({ render: () => h(App, props) })
      .use(plugin)
      .mount(el)
  },

  // Tanpa bar progres: umpan balik pemuatan sudah dipegang tombol yang
  // berputar di tiap form, dan bar tipis di puncak layar cuma berkedip sekejap.
  progress: false,
})

// Didaftarkan di dev juga: tanpa service worker aktif, browser tidak pernah
// menawarkan "Install". Aman untuk HMR karena aset dev disajikan dari origin
// lain (:5173) dan sudah diabaikan sw.js.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(() => {
      // PWA gagal dipasang bukan alasan aplikasi ikut gagal.
    })
  })
}
