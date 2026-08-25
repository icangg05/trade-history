<script setup lang="ts">
import { computed, ref } from 'vue'
import { Head, router } from '@inertiajs/vue3'
import { ChevronDown } from '@lucide/vue'

import PnlCalendar from '@/components/PnlCalendar.vue'
import StopBadge from '@/components/StopBadge.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { clock, longDate, money, monthLabel, num, pnlClass, useCurrency } from '@/composables/useFormat'
import { frameClass, frameGap } from '@/composables/useGroupFrame'
import type { DayStat, Trade } from '@/types'

const props = defineProps<{
  month: string
  gridStart: string
  gridEnd: string
  days: Record<string, DayStat>
  violations: Record<string, string[]>
  trades: Record<string, Trade[]>
  monthTotal: Record<string, DayStat>
}>()

const currency = useCurrency()
const selected = ref<string | null>(null)

const totals = computed(() => {
  const list = Object.values(props.monthTotal)

  return {
    pnl: list.reduce((sum, d) => sum + d.pnl, 0),
    trades: list.reduce((sum, d) => sum + d.trades, 0),
    wins: list.reduce((sum, d) => sum + d.wins, 0),
    green: list.filter((d) => d.pnl > 0).length,
    red: list.filter((d) => d.pnl < 0).length,
  }
})

function shift(offset: number) {
  const [year, month] = props.month.split('-').map(Number)
  const target = new Date(year, month - 1 + offset, 1)
  const value = `${target.getFullYear()}-${String(target.getMonth() + 1).padStart(2, '0')}`

  router.get('/calendar', { month: value }, { preserveState: true, preserveScroll: true })
}

const dayTrades = computed(() => (selected.value ? (props.trades[selected.value] ?? []) : []))
const dayStat = computed(() => (selected.value ? props.days[selected.value] : undefined))

/**
 * Trade dikelompokkan menurut hari tutupnya, jadi jam bukanya bisa jatuh di hari
 * sebelumnya. Selama masih hari yang sama cukup jamnya, karena tanggalnya sudah
 * jadi judul modal; kalau beda, tanggalnya ikut ditulis singkat.
 */
const shortDay = new Intl.DateTimeFormat('id-ID', { day: '2-digit', month: '2-digit' })

function openedLabel(trade: Trade): string {
  const time = clock(trade.opened_at)

  return trade.opened_at.slice(0, 10) === selected.value
    ? time
    : `${shortDay.format(new Date(trade.opened_at))} ${time}`
}

/** Angka yang tidak dikirim server tapi bisa dihitung dari daftar trade hari itu. */
const dayLots = computed(() => dayTrades.value.reduce((sum, t) => sum + (t.lot ?? 0), 0))
const dayWinRate = computed(() => {
  const stat = dayStat.value

  return stat && stat.trades ? (stat.wins / stat.trades) * 100 : null
})
</script>

<template>
  <Head title="Kalender" />

  <div class="space-y-4">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-semibold">{{ monthLabel(month) }}</h1>
        <p class="tnum font-mono text-sm" :class="totals.pnl >= 0 ? 'text-success' : 'text-destructive'">
          {{ money(totals.pnl, currency, true) }}
          <span class="text-muted-foreground">
            · {{ totals.trades }} trade · {{ totals.green }} hari hijau / {{ totals.red }} merah
          </span>
        </p>
      </div>

      <div class="flex items-center gap-1">
        <Button variant="outline" size="icon-sm" @click="shift(-1)">
          <ChevronDown class="size-4 rotate-90" />
        </Button>
        <Button variant="outline" size="sm" @click="router.get('/calendar')">Bulan ini</Button>
        <Button variant="outline" size="icon-sm" @click="shift(1)">
          <ChevronDown class="size-4 -rotate-90" />
        </Button>
      </div>
    </div>

    <PnlCalendar
      :month="month"
      :grid-start="gridStart"
      :grid-end="gridEnd"
      :days="days"
      :violations="violations"
      :currency="currency"
      @select="selected = $event"
    />

    <p class="text-[11px] text-muted-foreground">
      Titik emas di pojok sel menandai hari yang melanggar aturan akun ini.
    </p>

    <Dialog :open="selected !== null" @update:open="(value) => !value && (selected = null)">
      <DialogContent class="sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>{{ selected ? longDate(selected) : '' }}</DialogTitle>
        </DialogHeader>

        <div v-if="dayStat" class="grid grid-cols-2 gap-x-4 gap-y-2 sm:grid-cols-4">
          <div>
            <p class="text-[11px] text-muted-foreground">P/L hari ini</p>
            <p class="tnum font-mono text-sm" :class="pnlClass(dayStat.pnl)">
              {{ money(dayStat.pnl, currency, true) }}
            </p>
          </div>
          <div>
            <p class="text-[11px] text-muted-foreground">Trade</p>
            <p class="tnum font-mono text-sm">
              {{ dayStat.trades }}
              <span class="text-xs text-muted-foreground">
                {{ dayStat.wins }}W / {{ dayStat.losses }}L
              </span>
            </p>
          </div>
          <div>
            <p class="text-[11px] text-muted-foreground">Winrate</p>
            <p class="tnum font-mono text-sm">{{ dayWinRate === null ? '—' : `${num(dayWinRate, 0)}%` }}</p>
          </div>
          <div>
            <p class="text-[11px] text-muted-foreground">Total lot</p>
            <p class="tnum font-mono text-sm">{{ num(dayLots, 2) }}</p>
          </div>
        </div>

        <div v-if="selected && violations[selected]" class="rounded-md border border-gold/40 bg-gold/5 p-2 text-xs text-gold">
          {{ violations[selected].join(' · ') }}
        </div>

        <p v-if="!dayTrades.length" class="py-6 text-center text-sm text-muted-foreground">
          Tidak ada trade tertutup di hari ini.
        </p>

        <!-- Ponsel: satu baris per trade. Tanggalnya sudah jadi judul modal, jadi
             kolom waktu cukup jamnya dan sisa ruangnya dipakai untuk setup + lot. -->
        <ul v-else class="table-scroll max-h-[50vh] divide-y overflow-y-auto pr-3 sm:hidden">
          <template v-for="(trade, index) in dayTrades" :key="trade.id">
            <li v-if="frameGap(dayTrades, index)" class="mx-2 h-2 border-b-gold/40" />

            <li
              class="flex items-start justify-between gap-3 px-2 py-2.5"
              :class="[frameClass(dayTrades, index)]"
            >
              <div class="min-w-0">
                <p class="flex items-center gap-1.5">
                  <span class="tnum shrink-0 font-mono text-xs text-muted-foreground">
                    {{ openedLabel(trade) }}
                  </span>
                  <span class="truncate text-sm font-medium">{{ trade.symbol }}</span>
                  <Badge
                    :variant="trade.direction === 'buy' ? 'default' : 'secondary'"
                    class="shrink-0 text-[10px]"
                  >
                    {{ trade.direction === 'buy' ? 'BUY' : 'SELL' }}
                  </Badge>
                  <StopBadge :state="trade.stop_state" />
                </p>
                <p class="truncate text-[11px] text-muted-foreground">
                  <template v-if="trade.setup">{{ trade.setup }} · </template>{{ num(trade.lot, 2) }} lot
                </p>
              </div>

              <div class="shrink-0 text-right">
                <p class="tnum font-mono text-sm" :class="pnlClass(trade.pnl)">
                  {{ money(trade.pnl, currency, true) }}
                </p>
                <p class="tnum font-mono text-[11px] text-muted-foreground">
                  {{ trade.rr_realized === null ? '—' : `${num(trade.rr_realized)}R` }}
                </p>
              </div>
            </li>
          </template>
        </ul>

        <div v-if="dayTrades.length" class="table-scroll hidden max-h-[55vh] overflow-auto pr-4 sm:block">
          <table class="w-full text-xs sm:text-sm">
            <thead class="text-left text-[11px] uppercase text-muted-foreground">
              <tr>
                <th class="pb-2 font-medium">Waktu</th>
                <th class="pb-2 font-medium">Simbol</th>
                <th class="pb-2 font-medium">Arah</th>
                <th class="pb-2 text-right font-medium">Lot</th>
                <th class="pb-2 text-right font-medium">RR</th>
                <th class="pb-2 text-right font-medium">P/L</th>
              </tr>
            </thead>
            <tbody class="divide-y">
              <template v-for="(trade, index) in dayTrades" :key="trade.id">
              <tr v-if="frameGap(dayTrades, index)" class="h-2 border-b-gold/40"><td colspan="6" class="p-0" /></tr>

              <tr :class="frameClass(dayTrades, index)">
                <td class="tnum py-2 font-mono text-xs text-muted-foreground">{{ openedLabel(trade) }}</td>
                <td class="py-2">
                  <span class="inline-flex items-center gap-1.5">
                    {{ trade.symbol }}
                    <StopBadge :state="trade.stop_state" />
                  </span>
                  <span v-if="trade.setup" class="block text-[11px] text-muted-foreground">{{ trade.setup }}</span>
                </td>
                <td class="py-2">
                  <Badge :variant="trade.direction === 'buy' ? 'default' : 'secondary'" class="text-[10px]">
                    {{ trade.direction === 'buy' ? 'BUY' : 'SELL' }}
                  </Badge>
                </td>
                <td class="py-2 text-right"><span class="tnum font-mono text-xs">{{ num(trade.lot, 2) }}</span></td>
                <td class="tnum py-2 text-right font-mono text-xs">
                  {{ trade.rr_realized === null ? '—' : `${num(trade.rr_realized)}R` }}
                </td>
                <td class="tnum py-2 text-right font-mono" :class="pnlClass(trade.pnl)">
                  {{ money(trade.pnl, currency, true) }}
                </td>
              </tr>
              </template>
            </tbody>
          </table>
        </div>
      </DialogContent>
    </Dialog>
  </div>
</template>
