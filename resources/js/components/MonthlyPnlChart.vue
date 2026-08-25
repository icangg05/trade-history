<script setup lang="ts">
import { computed } from 'vue'
import { ArrowDown, ArrowUp, Info } from '@lucide/vue'
import { compact, money, pct } from '@/composables/useFormat'

const props = defineProps<{
  data: { month: string; pnl: number; profit: number; loss: number }[]
  currency: string
  /** Modal + arus kas, dipakai untuk badge persentase. Null = badge disembunyikan. */
  base?: number | null
}>()

/** Langkah sumbu yang "bulat": 1, 2, atau 5 dikali pangkat sepuluh. */
function niceStep(raw: number): number {
  const mag = 10 ** Math.floor(Math.log10(raw))
  const n = raw / mag

  return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10) * mag
}

/** Rentang sumbu Y: selalu memuat nol, dibulatkan ke kelipatan langkahnya. */
const axis = computed(() => {
  const values = props.data.map((d) => d.pnl)
  const step = niceStep((Math.max(0, ...values) - Math.min(0, ...values)) / 4 || 1)

  let top = Math.ceil(Math.max(0, ...values) / step) * step
  let bottom = Math.floor(Math.min(0, ...values) / step) * step
  if (top === bottom) [top, bottom] = [step, -step]

  const span = top - bottom
  // Dihitung per indeks, bukan akumulasi `v += step`: penjumlahan float
  // menggeser nol jadi 5e-17 dan garis nol kehilangan gayanya.
  const ticks = Array.from({ length: Math.round(span / step) + 1 }, (_, i) => {
    const value = Number((bottom + i * step).toFixed(6))

    return { value, pos: `${((value - bottom) / span) * 100}%` }
  })

  return { bottom, span, zero: ((0 - bottom) / span) * 100, ticks }
})

/** "2026-03" → label dua baris: "Mar", dan "'26" hanya saat tahunnya berganti. */
const bars = computed(() =>
  props.data.map((item, index) => {
    const date = new Date(`${item.month}-01T00:00:00`)
    const height = item.pnl === 0 ? 0 : Math.max((Math.abs(item.pnl) / axis.value.span) * 100, 1.2)

    return {
      ...item,
      label: date.toLocaleDateString('id-ID', { month: 'short' }),
      year: String(date.getFullYear()).slice(-2),
      showYear: index === 0 || item.month.endsWith('-01'),
      height: `${height}%`,
      bottom: `${item.pnl >= 0 ? axis.value.zero : axis.value.zero - height}%`,
    }
  }),
)

/** Profit & loss di sini kotor (semua trade untung / semua trade rugi),
 *  bukan penjumlahan bulan positif & negatif — angka atas yang bersih. */
const totals = computed(() =>
  props.data.reduce(
    (sum, item) => ({
      net: sum.net + item.pnl,
      profit: sum.profit + item.profit,
      loss: sum.loss + item.loss,
    }),
    { net: 0, profit: 0, loss: 0 },
  ),
)

const changePct = computed(() =>
  props.base && props.base > 0 ? (totals.value.net / props.base) * 100 : null,
)
</script>

<template>
  <div class="space-y-3">
    <div class="flex items-start justify-between gap-2">
      <p
        class="tnum font-mono text-xl leading-tight font-semibold"
        :class="totals.net > 0 ? 'text-success' : totals.net < 0 ? 'text-destructive' : ''"
      >
        {{ money(totals.net, currency, true) }}
      </p>

      <span
        v-if="changePct !== null"
        class="flex shrink-0 items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-medium"
        :class="changePct >= 0 ? 'bg-success/15 text-success' : 'bg-destructive/15 text-destructive'"
        title="Perubahan terhadap modal awal + arus kas"
      >
        <component :is="changePct >= 0 ? ArrowUp : ArrowDown" class="size-3" />
        {{ pct(changePct, 2) }}
        <Info class="size-3 opacity-60" />
      </span>
    </div>

    <!-- Batang tumbuh dari garis nol: hijau ke atas, merah ke bawah. Tiap kolom
         `min-w-0` supaya dua belas bulan tetap muat tanpa menggeser halaman. -->
    <div class="pt-2">
      <div class="relative h-40">
        <div
          v-for="tick in axis.ticks"
          :key="`g-${tick.value}`"
          class="absolute right-0 left-12 border-t"
          :class="tick.value === 0 ? 'border-border' : 'border-dashed border-border/40'"
          :style="{ bottom: tick.pos }"
        />

        <span
          v-for="tick in axis.ticks"
          :key="`t-${tick.value}`"
          class="tnum absolute left-0 w-10 translate-y-1/2 text-right font-mono text-[9px] text-muted-foreground/70"
          :style="{ bottom: tick.pos }"
        >
          {{ compact(tick.value) }}
        </span>

        <div class="absolute inset-y-0 right-0 left-12 flex gap-1">
          <div
            v-for="item in bars"
            :key="item.month"
            class="group relative min-w-0 flex-1"
            :title="`${item.label} 20${item.year}: ${money(item.pnl, currency, true)}`"
          >
            <div
              v-if="item.pnl !== 0"
              class="absolute inset-x-0 rounded-[2px] transition-colors"
              :class="item.pnl > 0 ? 'bg-success/70 group-hover:bg-success' : 'bg-destructive/70 group-hover:bg-destructive'"
              :style="{ bottom: item.bottom, height: item.height }"
            />
          </div>
        </div>
      </div>

      <div class="mt-1.5 ml-12 flex gap-1">
        <div v-for="item in bars" :key="`x-${item.month}`" class="min-w-0 flex-1 text-center">
          <p class="truncate text-[10px] leading-tight text-muted-foreground">{{ item.label }}</p>
          <p v-if="item.showYear" class="tnum truncate font-mono text-[9px] leading-tight text-muted-foreground/60">
            '{{ item.year }}
          </p>
        </div>
      </div>
    </div>

    <div class="space-y-1 border-t pt-2.5 text-xs">
      <p class="flex items-center gap-2">
        <span class="size-2 shrink-0 rounded-full bg-success" />
        <span class="text-muted-foreground">Profit</span>
        <span class="tnum ml-auto font-mono text-success">{{ money(totals.profit, currency, true) }}</span>
      </p>
      <p class="flex items-center gap-2">
        <span class="size-2 shrink-0 rounded-full bg-destructive" />
        <span class="text-muted-foreground">Loss</span>
        <span class="tnum ml-auto font-mono text-destructive">{{ money(totals.loss, currency, true) }}</span>
      </p>
    </div>
  </div>
</template>
