<script setup lang="ts">
import { computed } from 'vue'
import { router } from '@inertiajs/vue3'
import { ChevronLeft, ChevronRight } from '@lucide/vue'

import { Button } from '@/components/ui/button'
import type { Paginated } from '@/types'

const props = defineProps<{
  /** Paginator apa adanya dari controller. */
  meta: Paginated<unknown>
  /** Kata benda untuk baris jumlah: "trade", "transaksi". */
  label?: string
}>()

// Elemen pertama dan terakhir adalah tombol previous/next bawaan Laravel —
// keduanya digambar sendiri sebagai panah, jadi sisanya tinggal nomor halaman.
const pages = computed(() => props.meta.links.slice(1, -1))

function go(url: string | null) {
  if (url) router.get(url, {}, { preserveScroll: true })
}
</script>

<template>
  <nav v-if="meta.last_page > 1" class="flex items-center justify-between gap-3" aria-label="Navigasi halaman">
    <p class="hidden text-[11px] text-muted-foreground sm:block">
      <span class="tnum font-mono text-foreground">{{ meta.from }}–{{ meta.to }}</span>
      dari <span class="tnum font-mono text-foreground">{{ meta.total }}</span>
      <template v-if="label"> {{ label }}</template>
    </p>

    <div class="flex flex-1 items-center justify-center gap-1 sm:flex-none sm:justify-end">
      <Button
        variant="outline"
        size="icon-sm"
        :disabled="!meta.prev_page_url"
        aria-label="Halaman sebelumnya"
        @click="go(meta.prev_page_url)"
      >
        <ChevronLeft />
      </Button>

      <!-- Ponsel: nomor halaman diringkas jadi satu penanda. Sepuluh tombol
           berjajar tidak akan muat di layar selebar 360px. -->
      <span class="tnum px-3 font-mono text-xs text-muted-foreground sm:hidden">
        {{ meta.current_page }} / {{ meta.last_page }}
      </span>

      <div class="hidden items-center gap-1 sm:flex">
        <template v-for="(link, index) in pages" :key="index">
          <span v-if="!link.url" class="px-1 text-xs text-muted-foreground">…</span>
          <Button
            v-else
            size="icon-sm"
            :variant="link.active ? 'default' : 'ghost'"
            :aria-current="link.active ? 'page' : undefined"
            class="tnum font-mono text-xs"
            @click="go(link.url)"
          >
            {{ link.label }}
          </Button>
        </template>
      </div>

      <Button
        variant="outline"
        size="icon-sm"
        :disabled="!meta.next_page_url"
        aria-label="Halaman berikutnya"
        @click="go(meta.next_page_url)"
      >
        <ChevronRight />
      </Button>
    </div>
  </nav>
</template>
