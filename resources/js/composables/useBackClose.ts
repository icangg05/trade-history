import { watch, type Ref } from 'vue'
import { useEventListener } from '@vueuse/core'

/**
 * Tombol kembali menutup overlay-nya, bukan meninggalkan halaman — di ponsel itu
 * gerakan refleks untuk keluar dari tampilan penuh layar. Caranya satu entri
 * riwayat semu saat dibuka, dan dipulangkan lagi saat ditutup dengan cara lain.
 *
 * State Inertia ikut disalin supaya entri ini tidak mengosongkan data halaman
 * kalau riwayatnya berhenti di sini.
 */
export function useBackClose<T>(open: Ref<T | null>) {
  watch(open, (value) => {
    if (value) history.pushState({ ...history.state, overlay: true }, '')
    else if (history.state?.overlay) history.back()
  })

  useEventListener('popstate', () => (open.value = null))
}
