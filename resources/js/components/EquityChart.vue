<script setup lang="ts">
import { computed, ref } from 'vue'
import { useElementSize } from '@vueuse/core'
import { longDate, money, num } from '@/composables/useFormat'
import type { EquityPoint } from '@/types'

const props = withDefaults(
  defineProps<{
    points: EquityPoint[]
    currency: string
    height?: number
    /** 'balance' = saldo berjalan, 'pnl' = P/L kumulatif dari titik awal. */
    mode?: 'balance' | 'pnl'
  }>(),
  { height: 280, mode: 'balance' },
)

const wrap = ref<HTMLElement | null>(null)
const { width } = useElementSize(wrap)
const hover = ref<number | null>(null)

const PAD = { top: 14, right: 62, bottom: 22, left: 8 }

const series = computed(() => {
  if (props.mode === 'balance') return props.points.map((p) => p.balance)

  // P/L kumulatif: saldo dikurangi modal awal dan seluruh setoran/penarikan,
  // supaya deposit tidak terbaca sebagai "profit".
  const base = props.points[0]?.balance ?? 0
  let flow = 0

  return props.points.map((p) => {
    flow += p.flow
    return p.balance - base - flow
  })
})

const box = computed(() => {
  // Ikut lebar wadah apa adanya. Lantai yang lebih besar dari lebar sebenarnya
  // membuat isi SVG tergambar di luar kotaknya dan halaman jadi bisa digeser.
  const w = Math.max(width.value, 1)

  return {
    w,
    h: props.height,
    iw: Math.max(w - PAD.left - PAD.right, 1),
    ih: props.height - PAD.top - PAD.bottom,
  }
})

const scale = computed(() => {
  const values = series.value
  const times = props.points.map((p) => new Date(p.date).getTime())

  const yMin = Math.min(...values, 0)
  const yMax = Math.max(...values, 0)
  const span = yMax - yMin || Math.abs(yMax) || 1
  const lo = yMin - span * 0.08
  const hi = yMax + span * 0.08

  const tMin = Math.min(...times)
  const tSpan = Math.max(...times) - tMin || 1

  return {
    x: (i: number) => PAD.left + ((times[i] - tMin) / tSpan) * box.value.iw,
    y: (v: number) => PAD.top + (1 - (v - lo) / (hi - lo)) * box.value.ih,
    lo,
    hi,
  }
})

const path = computed(() => {
  if (!props.points.length) return ''

  return series.value.map((v, i) => `${i === 0 ? 'M' : 'L'}${scale.value.x(i).toFixed(1)},${scale.value.y(v).toFixed(1)}`).join(' ')
})

const areaPath = computed(() => {
  if (!path.value) return ''
  const base = scale.value.y(Math.max(scale.value.lo, 0))
  const last = scale.value.x(props.points.length - 1)

  return `${path.value} L${last.toFixed(1)},${base.toFixed(1)} L${PAD.left},${base.toFixed(1)} Z`
})

/** Tiga garis bantu: bawah, tengah, atas. */
const gridLines = computed(() =>
  [0, 0.5, 1].map((t) => {
    const value = scale.value.lo + (scale.value.hi - scale.value.lo) * t
    return { value, y: scale.value.y(value) }
  }),
)

const flowPoints = computed(() =>
  props.points.map((p, i) => ({ ...p, i })).filter((p) => p.flow !== 0),
)

const active = computed(() => (hover.value === null ? null : props.points[hover.value]))

function onMove(event: MouseEvent) {
  if (!props.points.length) return

  const rect = (event.currentTarget as SVGElement).getBoundingClientRect()
  const x = event.clientX - rect.left
  let best = 0

  for (let i = 1; i < props.points.length; i++) {
    if (Math.abs(scale.value.x(i) - x) < Math.abs(scale.value.x(best) - x)) best = i
  }

  hover.value = best
}

const tooltipLeft = computed(() => {
  if (hover.value === null) return 0
  const x = scale.value.x(hover.value)

  return Math.min(Math.max(x, 70), box.value.w - 70)
})
</script>

<template>
  <div ref="wrap" class="relative w-full">
    <svg
      :width="box.w"
      :height="box.h"
      class="block w-full select-none overflow-visible"
      @mousemove="onMove"
      @mouseleave="hover = null"
    >
      <defs>
        <linearGradient :id="`eq-${mode}`" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="hsl(var(--gold))" stop-opacity="0.28" />
          <stop offset="100%" stop-color="hsl(var(--gold))" stop-opacity="0" />
        </linearGradient>
      </defs>

      <g>
        <line
          v-for="line in gridLines"
          :key="line.y"
          :x1="PAD.left"
          :x2="box.w - PAD.right"
          :y1="line.y"
          :y2="line.y"
          stroke="hsl(var(--border))"
          stroke-dasharray="3 4"
          stroke-width="1"
        />
        <text
          v-for="line in gridLines"
          :key="`t-${line.y}`"
          :x="box.w - PAD.right + 8"
          :y="line.y + 3"
          class="fill-muted-foreground font-mono text-[10px]"
        >
          {{ num(line.value, 0) }}
        </text>
      </g>

      <path v-if="areaPath" :d="areaPath" :fill="`url(#eq-${mode})`" />
      <path v-if="path" :d="path" fill="none" stroke="hsl(var(--gold))" stroke-width="2" stroke-linejoin="round" />

      <!-- Hari dengan deposit / withdrawal ditandai titik cyan. -->
      <circle
        v-for="p in flowPoints"
        :key="`f-${p.i}`"
        :cx="scale.x(p.i)"
        :cy="scale.y(series[p.i])"
        r="3.5"
        fill="hsl(var(--background))"
        stroke="hsl(var(--cyan))"
        stroke-width="2"
      />

      <g v-if="hover !== null">
        <line
          :x1="scale.x(hover)"
          :x2="scale.x(hover)"
          :y1="PAD.top"
          :y2="box.h - PAD.bottom"
          stroke="hsl(var(--gold) / 0.45)"
          stroke-width="1"
        />
        <circle :cx="scale.x(hover)" :cy="scale.y(series[hover])" r="4" fill="hsl(var(--gold))" />
      </g>

      <text
        v-if="points.length"
        :x="PAD.left"
        :y="box.h - 4"
        class="fill-muted-foreground font-mono text-[10px]"
      >
        {{ longDate(points[0].date) }}
      </text>
      <text
        v-if="points.length > 1"
        :x="box.w - PAD.right"
        :y="box.h - 4"
        text-anchor="end"
        class="fill-muted-foreground font-mono text-[10px]"
      >
        {{ longDate(points[points.length - 1].date) }}
      </text>
    </svg>

    <div
      v-if="active"
      class="glass pointer-events-none absolute top-1 -translate-x-1/2 rounded-md px-2.5 py-1.5 text-xs shadow-lg"
      :style="{ left: `${tooltipLeft}px` }"
    >
      <p class="text-muted-foreground">{{ longDate(active.date) }}</p>
      <p class="tnum font-mono font-semibold">{{ money(series[hover!], currency) }}</p>
      <p v-if="active.pnl" class="tnum font-mono text-[11px]" :class="active.pnl > 0 ? 'text-success' : 'text-destructive'">
        {{ money(active.pnl, currency, true) }} dari trading
      </p>
      <p v-if="active.flow" class="tnum font-mono text-[11px] text-cyan">
        {{ money(active.flow, currency, true) }} {{ active.flow > 0 ? 'deposit' : 'withdrawal' }}
      </p>
    </div>

    <p v-if="!points.length" class="py-16 text-center text-sm text-muted-foreground">Belum ada data.</p>
  </div>
</template>
