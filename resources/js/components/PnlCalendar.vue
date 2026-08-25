<script setup lang="ts">
import { computed } from 'vue'
import { compact, money } from '@/composables/useFormat'
import type { DayStat } from '@/types'

const props = defineProps<{
  month: string
  gridStart: string
  gridEnd: string
  days: Record<string, DayStat>
  violations: Record<string, string[]>
  currency: string
}>()

const emit = defineEmits<{ select: [date: string] }>()

const WEEKDAYS = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']

function iso(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

const today = iso(new Date())

/** Semua tanggal dari Senin pertama sampai Minggu terakhir, dipotong per minggu. */
const weeks = computed(() => {
  const [y, m, d] = props.gridStart.split('-').map(Number)
  const cursor = new Date(y, m - 1, d)
  const end = props.gridEnd
  const out: { date: string; inMonth: boolean; stat?: DayStat; flagged: boolean }[][] = []

  let week: (typeof out)[number] = []

  while (iso(cursor) <= end) {
    const date = iso(cursor)

    week.push({
      date,
      inMonth: date.startsWith(props.month),
      stat: props.days[date],
      flagged: !!props.violations[date],
    })

    if (week.length === 7) {
      out.push(week)
      week = []
    }

    cursor.setDate(cursor.getDate() + 1)
  }

  return out
})

const maxAbs = computed(() => Math.max(...Object.values(props.days).map((d) => Math.abs(d.pnl)), 1))

/** Warna sel: hijau/merah dengan opasitas mengikuti besar P/L. */
function heat(stat?: DayStat): Record<string, string> {
  if (!stat || stat.pnl === 0) return {}

  const alpha = 0.1 + (Math.abs(stat.pnl) / maxAbs.value) * 0.28
  const hue = stat.pnl > 0 ? '--success' : '--destructive'

  return { backgroundColor: `hsl(var(${hue}) / ${alpha.toFixed(3)})` }
}

function weekTotal(week: { stat?: DayStat }[]): number {
  return week.reduce((sum, day) => sum + (day.stat?.pnl ?? 0), 0)
}
</script>

<template>
  <!-- Ponsel: 7 kolom tanpa total mingguan, supaya muat tanpa geser ke samping.
       Mulai sm: kolom total mingguan ikut tampil. -->
  <div class="glass-card table-scroll overflow-x-auto p-2 sm:p-3">
    <div class="sm:min-w-[42rem]">
      <div class="grid grid-cols-7 gap-1 pb-1.5 sm:grid-cols-8 sm:gap-1.5">
        <div v-for="name in WEEKDAYS" :key="name" class="text-center text-[10px] font-medium text-muted-foreground sm:text-[11px]">
          {{ name }}
        </div>
        <div class="hidden text-center text-[11px] font-medium text-muted-foreground sm:block">Minggu</div>
      </div>

      <div v-for="(week, index) in weeks" :key="index" class="grid grid-cols-7 gap-1 pb-1 sm:grid-cols-8 sm:gap-1.5 sm:pb-1.5">
        <button
          v-for="day in week"
          :key="day.date"
          type="button"
          class="relative flex aspect-square flex-col overflow-hidden rounded-md border p-1 text-left transition-colors sm:p-1.5"
          :class="[
            day.inMonth ? 'border-border' : 'border-transparent opacity-35',
            day.stat ? 'hover:border-gold/50' : 'hover:border-border',
            day.date === today ? 'ring-1 ring-gold/60' : '',
          ]"
          :style="heat(day.stat)"
          :disabled="!day.stat"
          @click="emit('select', day.date)"
        >
          <span class="tnum font-mono text-[10px] leading-none text-muted-foreground sm:text-[11px]">
            {{ Number(day.date.slice(-2)) }}
          </span>

          <template v-if="day.stat">
            <span
              class="tnum mt-auto whitespace-nowrap font-mono text-[10px] font-semibold leading-none sm:text-xs"
              :class="day.stat.pnl >= 0 ? 'text-success' : 'text-destructive'"
            >
              <span class="sm:hidden">{{ compact(day.stat.pnl, true) }}</span>
              <span class="hidden sm:inline">{{ money(day.stat.pnl, currency, true) }}</span>
            </span>
            <span class="mt-0.5 whitespace-nowrap text-[9px] leading-none text-muted-foreground sm:mt-1 sm:text-[10px]">
              <span class="sm:hidden">{{ day.stat.wins }}W/{{ day.stat.losses }}L</span>
              <span class="hidden sm:inline">{{ day.stat.trades }}T · {{ day.stat.wins }}W/{{ day.stat.losses }}L</span>
            </span>
          </template>

          <span
            v-if="day.flagged"
            class="absolute right-1 top-1 size-1.5 rounded-full bg-gold sm:right-1.5 sm:top-1.5"
            :title="violations[day.date]?.join(', ')"
          />
        </button>

        <div class="hidden flex-col justify-center rounded-md bg-muted/30 px-1.5 text-center sm:flex">
          <span
            class="tnum font-mono text-xs font-semibold"
            :class="weekTotal(week) === 0 ? 'text-muted-foreground' : weekTotal(week) > 0 ? 'text-success' : 'text-destructive'"
          >
            {{ weekTotal(week) === 0 ? '—' : money(weekTotal(week), currency, true) }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
