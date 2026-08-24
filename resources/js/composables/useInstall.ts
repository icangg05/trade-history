import { computed, ref } from 'vue'

interface InstallPromptEvent extends Event {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}

// Status di tingkat modul: `beforeinstallprompt` hanya menyala sekali, jauh
// sebelum komponen mana pun sempat memasang listener.
const deferred = ref<InstallPromptEvent | null>(null)
const installed = ref(false)

/** Dipanggil sekali dari app.ts, sebelum aplikasi Vue dibuat. */
export function listenForInstall(): void {
  window.addEventListener('beforeinstallprompt', (event) => {
    // Tanpa preventDefault, Chrome memakai spanduknya sendiri dan event ini hangus.
    event.preventDefault()
    deferred.value = event as InstallPromptEvent
  })

  window.addEventListener('appinstalled', () => {
    deferred.value = null
    installed.value = true
  })
}

function isStandalone(): boolean {
  return (
    window.matchMedia('(display-mode: standalone)').matches ||
    // Safari iOS memakai properti non-standar ini.
    (navigator as Navigator & { standalone?: boolean }).standalone === true
  )
}

function isIos(): boolean {
  return /iphone|ipad|ipod/i.test(navigator.userAgent)
}

export function useInstall() {
  const standalone = isStandalone()

  // Safari iOS tidak pernah memicu `beforeinstallprompt`; satu-satunya jalan
  // adalah menu Bagikan, jadi menunya tetap ditampilkan dengan petunjuk manual.
  const needsManualSteps = computed(() => !standalone && !deferred.value && isIos())
  const available = computed(() => !installed.value && !standalone && (!!deferred.value || needsManualSteps.value))

  /** @returns pesan yang perlu ditampilkan, atau null kalau dialog asli muncul. */
  async function install(): Promise<string | null> {
    if (!deferred.value) {
      return 'Buka menu Bagikan di Safari, lalu pilih "Tambahkan ke Layar Utama".'
    }

    const event = deferred.value
    deferred.value = null

    await event.prompt()
    const { outcome } = await event.userChoice

    if (outcome === 'accepted') installed.value = true

    return null
  }

  return { available, install }
}
