<script setup lang="ts">
import { computed } from 'vue'
import { Head, Link, usePage } from '@inertiajs/vue3'
import { ArrowLeft, House, RotateCw } from '@lucide/vue'

import { Button } from '@/components/ui/button'
import type { PageProps } from '@/types'

/**
 * Satu halaman untuk semua kode galat. Isinya cuma kalimat yang menjelaskan apa
 * yang terjadi dan satu jalan keluar, karena di situasi ini pengunjung tidak
 * butuh apa pun selain itu.
 */
const props = defineProps<{ status: number }>()

const MESSAGES: Record<number, { title: string; text: string }> = {
  403: {
    title: 'Halaman ini tidak bisa dibuka',
    text: 'Akunmu tidak punya akses ke halaman ini. Kalau seharusnya punya, hubungi administrator aplikasi.',
  },
  404: {
    title: 'Halaman tidak ditemukan',
    text: 'Alamat yang kamu buka tidak ada, sudah dipindahkan, atau datanya sudah dihapus.',
  },
  419: {
    title: 'Sesi kamu sudah berakhir',
    text: 'Halaman ini dibiarkan terbuka terlalu lama. Muat ulang halamannya, lalu kirim lagi.',
  },
  429: {
    title: 'Terlalu banyak percobaan',
    text: 'Permintaan yang masuk terlalu sering. Tunggu sebentar sebelum mencoba lagi.',
  },
  500: {
    title: 'Ada masalah di server',
    text: 'Kesalahan ini terjadi di sisi kami dan sudah tercatat. Coba lagi beberapa saat lagi.',
  },
  503: {
    title: 'Aplikasi sedang dalam perawatan',
    text: 'Aplikasi sedang diperbarui dan sebentar lagi kembali. Coba lagi beberapa menit lagi.',
  },
}

const message = computed(
  () =>
    MESSAGES[props.status] ?? {
      title: 'Terjadi kesalahan',
      text: 'Permintaanmu tidak bisa diselesaikan. Coba muat ulang halamannya.',
    },
)

/** Beranda hanya berarti bagi yang sudah masuk; sisanya diarahkan ke halaman masuk. */
const signedIn = computed(() => !!usePage<PageProps>().props.auth?.user)

const reload = () => window.location.reload()
const back = () => window.history.back()
</script>

<template>
  <Head :title="String(status)" />

  <div class="relative grid min-h-dvh place-items-center px-4 py-6">
    <div class="bg-ornaments" aria-hidden="true">
      <div class="bg-grid" />
      <div class="blob blob-a" />
      <div class="blob blob-b" />
    </div>

    <div class="glass-card w-full max-w-md space-y-5 p-6 text-center">
      <div class="flex items-center justify-center gap-2.5">
        <img src="/icons/icon-192.png" alt="" class="size-8 rounded-lg" />
        <p class="font-semibold tracking-tight">Trade <span class="text-gold">History</span></p>
      </div>

      <div>
        <p class="tnum font-mono text-5xl font-semibold text-gold">{{ status }}</p>
        <h1 class="mt-3 text-lg font-semibold">{{ message.title }}</h1>
        <p class="mt-2 text-sm leading-relaxed text-muted-foreground">{{ message.text }}</p>
      </div>

      <div class="flex flex-col gap-2 sm:flex-row sm:justify-center">
        <Button v-if="status === 419" class="gap-1.5" @click="reload">
          <RotateCw class="size-4" /> Muat ulang
        </Button>

        <Button variant="outline" class="gap-1.5" @click="back">
          <ArrowLeft class="size-4" /> Kembali
        </Button>

        <Link :href="signedIn ? '/' : '/login'">
          <Button class="w-full gap-1.5">
            <House class="size-4" />
            {{ signedIn ? 'Beranda' : 'Halaman masuk' }}
          </Button>
        </Link>
      </div>
    </div>
  </div>
</template>
