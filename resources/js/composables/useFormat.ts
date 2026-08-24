import { computed } from 'vue'
import { usePage } from '@inertiajs/vue3'
import type { PageProps } from '@/types'

const LOCALE = 'id-ID'

export function useCurrency() {
  const page = usePage<PageProps>()

  return computed(() => page.props.currentAccount?.currency ?? 'USD')
}

export const CURRENCIES = [
  { code: 'USD', label: 'USD — Dolar AS' },
  { code: 'USC', label: 'USC — Sen dolar (akun cent)' },
  { code: 'IDR', label: 'IDR — Rupiah' },
] as const

export type CurrencyCode = (typeof CURRENCIES)[number]['code']

const DIGITS: Record<string, number> = { USD: 2, USC: 2, IDR: 0 }

/**
 * Uang lengkap dengan mata uang akun.
 *
 * USC (akun sen) bukan kode ISO 4217, jadi Intl akan menolaknya — nilainya
 * diformat sebagai angka biasa lalu diberi akhiran kodenya.
 */
export function money(value: number | null | undefined, currency = 'USD', signed = false): string {
  if (value === null || value === undefined) return '—'

  const digits = DIGITS[currency] ?? 2
  const magnitude = Math.abs(value)

  const text =
    currency === 'USC'
      ? `${num(magnitude, digits)} USC`
      : new Intl.NumberFormat(LOCALE, {
          style: 'currency',
          currency,
          maximumFractionDigits: digits,
          minimumFractionDigits: digits,
        }).format(magnitude)

  if (!signed) return value < 0 ? `-${text}` : text

  return value < 0 ? `−${text}` : value > 0 ? `+${text}` : text
}

export function num(value: number | null | undefined, digits = 2): string {
  if (value === null || value === undefined) return '—'

  return new Intl.NumberFormat(LOCALE, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(value)
}

/**
 * Harga instrumen: presisi mengikuti angka aslinya, bukan lebar kolom database.
 * `decimal(18,5)` selalu mengembalikan 5 desimal (4404.51000) — nol di ujung
 * tidak membawa informasi apa pun, jadi dibuang.
 */
export function price(value: number | null | undefined): string {
  if (value === null || value === undefined) return '—'

  return new Intl.NumberFormat(LOCALE, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 5,
  }).format(value)
}

/**
 * Angka pendek untuk sel sempit (kalender di layar ponsel): 1,2 rb / 15 jt.
 * Tanpa simbol mata uang — konteksnya sudah jelas dari halamannya.
 */
export function compact(value: number | null | undefined, signed = false): string {
  if (value === null || value === undefined) return '—'

  const text = new Intl.NumberFormat(LOCALE, { notation: 'compact', maximumFractionDigits: 1 }).format(
    Math.abs(value),
  )

  return value < 0 ? `−${text}` : signed && value > 0 ? `+${text}` : text
}

export function pct(value: number | null | undefined, digits = 1): string {
  return value === null || value === undefined ? '—' : `${num(value, digits)}%`
}

/** Satu bentuk tanggal untuk seluruh aplikasi: "5 Maret 2026". */
export function longDate(value: string | null | undefined): string {
  if (!value) return '—'

  return new Date(value).toLocaleDateString(LOCALE, { day: 'numeric', month: 'long', year: 'numeric' })
}

/** Tanggal yang sama plus jam: "5 Maret 2026, 14.05". */
export function dateTime(value: string | null | undefined): string {
  if (!value) return '—'

  const date = new Date(value)

  return `${longDate(value)}, ${date.toLocaleTimeString(LOCALE, { hour: '2-digit', minute: '2-digit' })}`
}

/** Jam saja: "14.05". Dipakai saat tanggalnya sudah jelas dari konteks. */
export function clock(value: string | null | undefined): string {
  if (!value) return '—'

  return new Date(value).toLocaleTimeString(LOCALE, { hour: '2-digit', minute: '2-digit' })
}

export function monthLabel(value: string): string {
  const [year, month] = value.split('-').map(Number)

  return new Date(year, month - 1, 1).toLocaleDateString(LOCALE, { month: 'long', year: 'numeric' })
}

/** Kelas warna standar: hijau untung, merah rugi, abu netral. */
export function pnlClass(value: number | null | undefined): string {
  if (value === null || value === undefined || value === 0) return 'text-muted-foreground'

  return value > 0 ? 'text-success' : 'text-destructive'
}
