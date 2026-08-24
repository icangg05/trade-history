<script setup lang="ts">
import { computed } from 'vue'
import { money } from '@/composables/useFormat'

const props = defineProps<{
  data: { month: string; pnl: number }[]
  currency: string
}>()

const max = computed(() => Math.max(...props.data.map((d) => Math.abs(d.pnl)), 1))

/** "2026-03" → label dua baris: "Mar" dan "'26". */
const bars = computed(() =>
  props.data.map((item) => {
    const date = new Date(`${item.month}-01T00:00:00`)

    return {
      ...item,
      label: date.toLocaleDateString('id-ID', { month: 'short' }),
      year: String(date.getFullYear()).slice(-2),
      height: `${Math.max((Math.abs(item.pnl) / max.value) * 100, item.pnl === 0 ? 0 : 4)}%`,
    }
  }),
)
</script>

<template>
  <!-- Batang tumbuh dari garis nol: hijau ke atas, merah ke bawah. Tiap kolom
       `min-w-0` supaya dua belas bulan tetap muat tanpa menggeser halaman. -->
  <div class="flex w-full items-stretch gap-1">
    <div
      v-for="item in bars"
      :key="item.month"
      class="group min-w-0 flex-1"
      :title="`${item.label} 20${item.year}: ${money(item.pnl, currency, true)}`"
    >
      <div class="flex h-28 flex-col">
        <div class="flex flex-1 items-end">
          <div
            v-if="item.pnl > 0"
            class="w-full rounded-t-sm bg-success/70 transition-colors group-hover:bg-success"
            :style="{ height: item.height }"
          />
        </div>

        <div class="h-px shrink-0 bg-border" />

        <div class="flex flex-1 items-start">
          <div
            v-if="item.pnl < 0"
            class="w-full rounded-b-sm bg-destructive/70 transition-colors group-hover:bg-destructive"
            :style="{ height: item.height }"
          />
        </div>
      </div>

      <p class="mt-1.5 truncate text-center text-[10px] leading-tight text-muted-foreground">{{ item.label }}</p>
      <p class="tnum truncate text-center font-mono text-[9px] leading-tight text-muted-foreground/60">
        '{{ item.year }}
      </p>
    </div>
  </div>
</template>
