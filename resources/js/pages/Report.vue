<script setup lang="ts">
import { computed, watch } from 'vue'
import { Head, usePage } from '@inertiajs/vue3'
import { useLocalStorage } from '@vueuse/core'
import { Download } from '@lucide/vue'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { num } from '@/composables/useFormat'
import type { PageProps } from '@/types'

const props = defineProps<{
  years: number[]
  defaultName: string
  accounts: { id: number; name: string; broker: string | null; currency: string; is_archived: boolean }[]
}>()

const page = usePage<PageProps>()
const errors = computed(() => page.props.errors as Record<string, string>)

const today = new Date().toISOString().slice(0, 10)

/** Akhir tahun pajak — atau hari ini, kalau tahunnya masih berjalan. */
const endOfYear = (year: string | number) => {
  const last = `${year}-12-31`

  return last > today ? today : last
}

// Identitas dan kurs tersimpan di peramban saja — tidak ada NPWP yang menginap
// di basis data hanya untuk mengisi satu kop laporan. `mergeDefaults` menambal
// isian yang tersimpan sebelum sebuah field ada, supaya tidak lahir kosong.
const form = useLocalStorage(
  'report-form',
  {
    year: String(props.years[0]),
    rate: '',
    rate_date: endOfYear(props.years[0]),
    name: props.defaultName,
    npwp: '',
    address: '',
  },
  { mergeDefaults: true },
)

/**
 * Tanggal kurs ikut pindah saat tahun pajak diganti. Tanpa ini tanggal tahun lalu
 * yang tersimpan di peramban akan ikut tercetak di laporan tahun ini — salah, dan
 * salahnya tidak kelihatan sampai dokumennya sudah di tangan petugas.
 */
watch(
  () => form.value.year,
  (year) => (form.value.rate_date = endOfYear(year)),
)

const foreign = computed(() => props.accounts.some((a) => a.currency !== 'IDR'))

/**
 * Cerminan `ReportController::decimal()`: koma hanya bisa berarti desimal, jadi
 * begitu ia muncul titik pasti pemisah ribuan. Hasil bacaannya ditampilkan kembali
 * di bawah isian supaya salah tafsir ketahuan sebelum PDF-nya diunduh, bukan setelah
 * dokumennya sampai di tangan petugas.
 */
const parsedRate = computed(() => {
  const raw = String(form.value.rate).trim()
  const value = Number(raw.includes(',') ? raw.replace(/\./g, '').replace(',', '.') : raw)

  return raw !== '' && Number.isFinite(value) && value > 0 ? value : null
})
</script>

<template>
  <Head title="Laporan" />

  <div class="space-y-4">
    <div>
      <h1 class="text-xl font-semibold">Laporan tahunan</h1>
      <p class="text-sm text-muted-foreground">
        Berkas PDF A4 landscape berisi rekonsiliasi saldo, rekap bulanan, mutasi dana, dan
        lampiran seluruh transaksi trade sepanjang satu tahun pajak, untuk dipegang saat
        petugas pajak meminta klarifikasi. Seluruh akun ikut, termasuk yang sudah diarsipkan.
      </p>
    </div>

    <form method="POST" action="/reports/pdf" class="grid gap-4 lg:grid-cols-3">
      <input type="hidden" name="_token" :value="page.props.csrf" />

      <div class="space-y-4 lg:col-span-2">
        <div class="glass-card space-y-4 p-4">
          <h2 class="text-sm font-semibold">Periode &amp; kurs</h2>

          <div class="grid gap-3 sm:grid-cols-3">
            <div class="space-y-1.5">
              <Label for="year">Tahun pajak</Label>
              <Select v-model="form.year" name="year">
                <SelectTrigger id="year" class="h-9 w-full" aria-label="Tahun pajak">
                  <SelectValue placeholder="Pilih tahun" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem v-for="y in years" :key="y" :value="String(y)">{{ y }}</SelectItem>
                </SelectContent>
              </Select>
              <p v-if="errors.year" class="text-[11px] text-destructive">{{ errors.year }}</p>
            </div>

            <div class="space-y-1.5">
              <Label for="rate">Kurs rupiah per 1 USD</Label>
              <Input
                id="rate"
                v-model="form.rate"
                name="rate"
                type="text"
                inputmode="decimal"
                autocomplete="off"
                placeholder="Contoh: 17.757,40"
              />
              <p v-if="parsedRate" class="text-[11px] text-muted-foreground">
                Terbaca Rp{{ num(parsedRate, 2) }} per 1 USD.
              </p>
              <p v-if="errors.rate" class="text-[11px] text-destructive">{{ errors.rate }}</p>
            </div>

            <div class="space-y-1.5">
              <Label for="rate_date">Kurs tanggal</Label>
              <Input id="rate_date" v-model="form.rate_date" name="rate_date" type="date" :max="today" />
              <p v-if="errors.rate_date" class="text-[11px] text-destructive">{{ errors.rate_date }}</p>
            </div>
          </div>

          <p class="text-[11px] text-muted-foreground">
            Kurs dan tanggalnya ikut dicetak di laporan supaya bisa diperiksa ulang. Isi dengan
            kurs yang punya sumber resmi, misalnya kurs pajak KMK di akhir tahun. Angka ini
            hanya dipakai untuk laba/rugi trading; setoran dan penarikan tetap memakai kurs
            yang sudah tercatat pada hari transaksinya masing-masing.
          </p>

          <p v-if="!foreign" class="text-[11px] text-muted-foreground">
            Semua akunmu bermata uang rupiah, jadi kursnya tidak akan mengubah angka apa pun.
          </p>
        </div>

        <div class="glass-card space-y-4 p-4">
          <h2 class="text-sm font-semibold">Identitas wajib pajak</h2>
          <p class="text-[11px] text-muted-foreground">
            Hanya dicetak di kop laporan. Tersimpan di peramban ini saja, tidak dikirim ke mana pun
            selain saat membuat PDF.
          </p>

          <div class="space-y-1.5">
            <Label for="name">Nama</Label>
            <Input
              id="name"
              v-model="form.name"
              name="name"
              required
              maxlength="255"
              placeholder="Nama lengkap sesuai kartu identitas"
            />
            <p v-if="errors.name" class="text-[11px] text-destructive">{{ errors.name }}</p>
          </div>

          <div class="space-y-1.5">
            <Label for="npwp">NPWP <span class="text-muted-foreground">(opsional)</span></Label>
            <Input
              id="npwp"
              v-model="form.npwp"
              name="npwp"
              maxlength="32"
              placeholder="00.000.000.0-000.000"
            />
            <p v-if="errors.npwp" class="text-[11px] text-destructive">{{ errors.npwp }}</p>
          </div>

          <div class="space-y-1.5">
            <Label for="address">Alamat <span class="text-muted-foreground">(opsional)</span></Label>
            <Textarea
              id="address"
              v-model="form.address"
              name="address"
              rows="2"
              maxlength="500"
              placeholder="Alamat sesuai yang terdaftar di NPWP"
            />
            <p v-if="errors.address" class="text-[11px] text-destructive">{{ errors.address }}</p>
          </div>
        </div>
      </div>

      <div class="space-y-4">
        <div class="glass-card space-y-3 p-4">
          <h2 class="text-sm font-semibold">Akun yang ikut</h2>
          <ul class="space-y-1.5 text-sm">
            <li v-for="a in accounts" :key="a.id" class="flex items-baseline justify-between gap-2">
              <span>
                {{ a.name }}
                <span v-if="a.is_archived" class="text-[11px] text-muted-foreground">(diarsipkan)</span>
              </span>
              <span class="shrink-0 text-xs text-muted-foreground">{{ a.broker || '—' }} · {{ a.currency }}</span>
            </li>
          </ul>
          <p class="text-[11px] text-muted-foreground">
            Akun arsip tetap dilaporkan: trade tahun itu tetap penghasilan tahun itu, dan
            menghilangkannya membuat laporan mengecilkan angka.
          </p>
        </div>

        <Button type="submit" class="w-full">
          <Download class="size-4" />
          Unduh PDF
        </Button>
      </div>
    </form>
  </div>
</template>
