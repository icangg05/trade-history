<script setup lang="ts">
import { computed, ref } from 'vue'
import { Head, router } from '@inertiajs/vue3'
import { ChevronDown } from '@lucide/vue'

import PnlCalendar from '@/components/PnlCalendar.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { dateTime, longDate, money, monthLabel, num, useCurrency } from '@/composables/useFormat'
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

        <div v-if="dayStat" class="flex flex-wrap gap-4 text-sm">
          <span class="tnum font-mono" :class="dayStat.pnl >= 0 ? 'text-success' : 'text-destructive'">
            {{ money(dayStat.pnl, currency, true) }}
          </span>
          <span class="text-muted-foreground">
            {{ dayStat.trades }} trade · {{ dayStat.wins }}W / {{ dayStat.losses }}L
          </span>
        </div>

        <div v-if="selected && violations[selected]" class="rounded-md border border-gold/40 bg-gold/5 p-2 text-xs text-gold">
          {{ violations[selected].join(' · ') }}
        </div>

        <div class="table-scroll max-h-80 overflow-auto">
          <table class="w-full text-xs sm:text-sm">
            <thead class="text-left text-[11px] uppercase text-muted-foreground">
              <tr>
                <th class="pb-2 font-medium">Waktu</th>
                <th class="pb-2 font-medium">Simbol</th>
                <th class="hidden pb-2 font-medium sm:table-cell">Arah</th>
                <th class="pb-2 text-right font-medium">RR</th>
                <th class="pb-2 text-right font-medium">P/L</th>
              </tr>
            </thead>
            <tbody class="divide-y">
              <tr v-for="trade in dayTrades" :key="trade.id">
                <td class="py-2 text-xs text-muted-foreground">{{ dateTime(trade.opened_at) }}</td>
                <td class="py-2">
                  <span class="flex items-center gap-1.5">
                    {{ trade.symbol }}
                    <!-- Di ponsel badge arah ikut di sini; kolomnya sendiri disembunyikan. -->
                    <Badge
                      :variant="trade.direction === 'buy' ? 'default' : 'secondary'"
                      class="text-[10px] sm:hidden"
                    >
                      {{ trade.direction === 'buy' ? 'BUY' : 'SELL' }}
                    </Badge>
                  </span>
                  <span v-if="trade.setup" class="block text-[11px] text-muted-foreground">{{ trade.setup }}</span>
                </td>
                <td class="hidden py-2 sm:table-cell">
                  <Badge :variant="trade.direction === 'buy' ? 'default' : 'secondary'" class="text-[10px]">
                    {{ trade.direction === 'buy' ? 'BUY' : 'SELL' }}
                  </Badge>
                </td>
                <td class="tnum py-2 text-right font-mono text-xs">
                  {{ trade.rr_realized === null ? '—' : `${num(trade.rr_realized)}R` }}
                </td>
                <td
                  class="tnum py-2 text-right font-mono"
                  :class="(trade.pnl ?? 0) >= 0 ? 'text-success' : 'text-destructive'"
                >
                  {{ money(trade.pnl, currency, true) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </DialogContent>
    </Dialog>
  </div>
</template>
