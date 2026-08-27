<script setup lang="ts">
import { CalendarDays, ListOrdered, ScrollText, Sparkles } from '@lucide/vue'

/**
 * Rangka halaman masuk dan daftar. Di layar lebar dibagi dua: kiri penjelasan
 * singkat tentang aplikasinya, kanan formulirnya. Di layar kecil penjelasan itu
 * disembunyikan supaya formulirnya muat dalam satu layar.
 */
defineProps<{ title: string; subtitle: string }>()

const FEATURES = [
  {
    icon: ListOrdered,
    title: 'Riwayat trade',
    text: 'Semua trade tersimpan dalam satu tempat, lengkap dengan entry, stop loss, take profit, hasil, dan catatan.',
  },
  {
    icon: CalendarDays,
    title: 'P/L harian',
    text: 'Lihat perkembangan profit dan loss setiap hari melalui kalender bulanan.',
  },
  {
    icon: ScrollText,
    title: 'Aturan trading',
    text: 'Catat batas risiko dan targetmu sendiri sebagai pengingat saat mengevaluasi hasil trading.',
  },
  {
    icon: Sparkles,
    title: 'Analisis dengan AI',
    text: 'Upload screenshot MetaTrader dan biarkan AI membantu membaca detail trade serta menemukan pola dari jurnalmu.',
  },
]
</script>

<template>
  <div class="relative min-h-dvh">
    <div class="bg-ornaments" aria-hidden="true">
      <div class="bg-grid" />
      <div class="blob blob-a" />
      <div class="blob blob-b" />
    </div>

    <div class="mx-auto grid min-h-dvh max-w-5xl items-center gap-10 px-4 py-6 lg:grid-cols-2 lg:gap-14">
      <section class="hidden lg:block">
        <div class="flex items-center gap-3">
          <img src="/icons/icon-192.png" alt="" class="size-11 rounded-xl" />
          <p class="text-xl font-semibold tracking-tight">Trade <span class="text-gold">History</span></p>
        </div>

        <h2 class="mt-7 text-3xl leading-tight font-semibold tracking-tight">
          Jurnal trading pribadi untuk mencatat setiap trade.
        </h2>
        <p class="mt-3 text-sm leading-relaxed text-muted-foreground">
          Simpan riwayat trade, catatan entry, hasil, dan alasan di balik setiap keputusan.
          Fokus pada apa yang sudah terjadi, supaya kamu bisa melihat dan mengevaluasi pola
          tradingmu dari waktu ke waktu.
        </p>

        <ul class="mt-8 space-y-4">
          <li v-for="item in FEATURES" :key="item.title" class="flex gap-3">
            <span class="mt-0.5 grid size-8 shrink-0 place-items-center rounded-lg bg-gold/10 text-gold">
              <component :is="item.icon" class="size-4" />
            </span>
            <div>
              <p class="text-sm font-medium">{{ item.title }}</p>
              <p class="text-xs leading-relaxed text-muted-foreground">{{ item.text }}</p>
            </div>
          </li>
        </ul>
      </section>

      <div class="glass-card mx-auto w-full max-w-md space-y-5 p-6">
        <div>
          <!-- Logo ikut tampil di kartu: di ponsel inilah satu-satunya tempat
               merek aplikasi terlihat. -->
          <div class="flex items-center gap-2.5 lg:hidden">
            <img src="/icons/icon-192.png" alt="" class="size-9 rounded-lg" />
            <p class="font-semibold tracking-tight">Trade <span class="text-gold">History</span></p>
          </div>

          <h1 class="mt-4 text-lg font-semibold lg:mt-0">{{ title }}</h1>
          <p class="mt-1 text-sm text-muted-foreground">{{ subtitle }}</p>
        </div>

        <slot />
      </div>
    </div>
  </div>
</template>
