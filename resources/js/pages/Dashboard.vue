<script setup lang="ts">
import { computed, ref } from 'vue'
import { Head, Link, router } from '@inertiajs/vue3'
import { Plus } from '@lucide/vue'

import EquityChart from '@/components/EquityChart.vue'
import MonthlyPnlChart from '@/components/MonthlyPnlChart.vue'
import RuleStatusBanner from '@/components/RuleStatusBanner.vue'
import StatCard from '@/components/StatCard.vue'
import StopBadge from '@/components/StopBadge.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { dateTime, longDate, money, num, pct } from '@/composables/useFormat'
import { frameClass, frameGap, frameTop } from '@/composables/useGroupFrame'
import type { EquityPoint, RuleStatus, Summary, Trade } from '@/types'

const props = defineProps<{
  range: string
  summary: Summary
  equity: EquityPoint[]
  monthly: { month: string; pnl: number; profit: number; loss: number }[]
  monthlyBase: number
  ruleStatus: RuleStatus
  recent: Trade[]
}>()

const RANGES = [
  { key: '30d', label: '30 hari' },
  { key: '90d', label: '90 hari' },
  { key: '1y', label: '1 tahun' },
  { key: 'all', label: 'Semua' },
]

const mode = ref<'balance' | 'pnl'>('balance')
const currency = computed(() => props.summary.currency)

/**
 * Pertumbuhan periode ini: P/L periode dibagi saldo di awal periode.
 *
 * Dasarnya sengaja bukan `modal awal + arus dana`: withdrawal mengecilkan angka
 * itu, jadi menarik dana bikin persennya meledak padahal tidak ada yang berubah
 * di hasil trading. Saldo pembukaan adalah modal yang benar-benar dipakai
 * selama periode ini, dan tidak ikut berubah saat dana ditarik setelahnya.
 */
const growthPct = computed(() => {
  const base = props.equity[0]?.balance ?? 0

  return base > 0 ? (props.summary.net_pnl / base) * 100 : 0
})
</script>

<template>
  <Head title="Dashboard" />

  <div class="space-y-5">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-semibold">Dashboard</h1>
        <p class="text-sm text-muted-foreground">
          {{ longDate(summary.period.from) }} — {{ longDate(summary.period.to) }}
        </p>
      </div>

      <div class="flex w-full items-center gap-2 sm:w-auto">
        <div class="flex min-w-0 flex-1 rounded-md border p-0.5 sm:flex-none">
          <button
            v-for="item in RANGES"
            :key="item.key"
            type="button"
            class="flex-1 rounded px-2 py-1 text-xs whitespace-nowrap transition-colors sm:flex-none"
            :class="range === item.key ? 'bg-accent text-accent-foreground' : 'text-muted-foreground hover:text-foreground'"
            @click="router.get('/', { range: item.key }, { preserveScroll: true })"
          >
            {{ item.label }}
          </button>
        </div>

        <Link href="/trades/create" class="shrink-0">
          <Button size="sm" class="gap-1.5"><Plus class="size-4" /> Trade</Button>
        </Link>
      </div>
    </div>

    <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
      <StatCard label="Saldo" :value="money(summary.balance, currency)" :hint="`Modal ${money(summary.initial_balance, currency)}`" tone="gold" />
      <StatCard
        label="P/L periode"
        :value="money(summary.net_pnl, currency, true)"
        :hint="`Pertumbuhan ${pct(growthPct)}`"
        :tone="summary.net_pnl >= 0 ? 'good' : 'bad'"
      />
      <StatCard label="Winrate" :value="pct(summary.win_rate_pct)" :hint="`${summary.wins}W / ${summary.losses}L / ${summary.breakeven}BE`" />
      <StatCard
        label="Profit factor"
        :value="summary.profit_factor === null ? '—' : num(summary.profit_factor)"
        :hint="`Ekspektasi ${money(summary.expectancy, currency, true)}`"
        :tone="(summary.profit_factor ?? 0) >= 1 ? 'good' : 'bad'"
      />
      <StatCard
        label="Max drawdown"
        :value="money(summary.max_drawdown.amount, currency)"
        :hint="pct(summary.max_drawdown.pct)"
        tone="bad"
      />
      <StatCard
        label="Rata-rata RR"
        :value="summary.avg_rr_realized === null ? '—' : `${num(summary.avg_rr_realized)}R`"
        :hint="summary.avg_rr_planned === null ? null : `Rencana ${num(summary.avg_rr_planned)}R`"
      />
    </div>

    <div class="grid gap-4 lg:grid-cols-3">
      <div class="glass-card p-4 lg:col-span-2">
        <div class="mb-2 flex items-center justify-between">
          <h2 class="text-sm font-semibold">Perkembangan akun</h2>
          <div class="flex rounded-md border p-0.5 text-xs">
            <button
              type="button"
              class="rounded px-2 py-0.5"
              :class="mode === 'balance' ? 'bg-accent text-accent-foreground' : 'text-muted-foreground'"
              @click="mode = 'balance'"
            >
              Saldo
            </button>
            <button
              type="button"
              class="rounded px-2 py-0.5"
              :class="mode === 'pnl' ? 'bg-accent text-accent-foreground' : 'text-muted-foreground'"
              @click="mode = 'pnl'"
            >
              P/L kumulatif
            </button>
          </div>
        </div>
        <EquityChart :points="equity" :currency="currency" :mode="mode" />
        <p class="mt-1 text-[11px] text-muted-foreground">
          Titik cyan menandai hari dengan deposit atau withdrawal.
        </p>
      </div>

      <RuleStatusBanner :status="ruleStatus" :currency="currency" />
    </div>

    <div class="grid items-start gap-4 lg:grid-cols-2">
      <div class="glass-card p-4">
        <h2 class="mb-2 text-sm font-semibold">P/L per bulan</h2>
        <MonthlyPnlChart :data="monthly" :currency="currency" :base="monthlyBase" />
      </div>

      <div class="glass-card p-4">
        <div class="mb-3 flex items-center justify-between">
          <h2 class="text-sm font-semibold">Trade terakhir</h2>
          <Link href="/trades" class="text-xs text-gold hover:underline">Lihat semua</Link>
        </div>

        <p v-if="!recent.length" class="py-8 text-center text-sm text-muted-foreground">Belum ada trade.</p>

        <ul v-else class="-mx-2 divide-y">
          <template v-for="(trade, index) in recent" :key="trade.id">
          <li v-if="frameGap(recent, index)" class="mx-2 h-2" :class="frameTop(recent, index)" />

          <li
            class="flex items-center gap-2 px-2 py-1.5"
            :class="[frameClass(recent, index)]"
          >
            <Badge
              :variant="trade.direction === 'buy' ? 'default' : 'secondary'"
              class="w-10 shrink-0 justify-center px-0 text-[9px]"
            >
              {{ trade.direction === 'buy' ? 'BUY' : 'SELL' }}
            </Badge>
            <div class="min-w-0 flex-1">
              <p class="truncate text-[13px] leading-tight font-medium">{{ trade.symbol }}</p>
              <p class="flex items-center gap-1 truncate text-[10px] leading-tight text-muted-foreground">
                <span class="truncate">{{ dateTime(trade.opened_at) }}</span>
                <StopBadge :state="trade.stop_state" />
              </p>
            </div>
            <span
              class="tnum shrink-0 font-mono text-xs"
              :class="trade.pnl >= 0 ? 'text-success' : 'text-destructive'"
            >
              {{ money(trade.pnl, currency, true) }}
            </span>
          </li>
          </template>
        </ul>
      </div>
    </div>
  </div>
</template>
