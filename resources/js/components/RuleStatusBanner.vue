<script setup lang="ts">
import { computed } from 'vue'
import { Link } from '@inertiajs/vue3'
import { money, num, pct } from '@/composables/useFormat'
import type { RuleStatus } from '@/types'

const props = defineProps<{ status: RuleStatus; currency: string }>()

const lossPct = computed(() => {
  if (!props.status.loss_limit) return 0

  return Math.min((props.status.loss_used / props.status.loss_limit) * 100, 100)
})

const profitPct = computed(() => {
  if (!props.status.profit_goal || props.status.pnl <= 0) return 0

  return Math.min((props.status.pnl / props.status.profit_goal) * 100, 100)
})

const breached = computed(
  () => props.status.loss_breached || props.status.trades_breached || props.status.drawdown_breached,
)
</script>

<template>
  <div
    class="glass-card p-4"
    :class="breached ? 'border-destructive/50' : status.profit_reached ? 'border-success/40' : ''"
  >
    <div class="flex flex-wrap items-baseline justify-between gap-2">
      <h2 class="text-sm font-semibold">Hari ini</h2>
      <span class="tnum font-mono text-sm" :class="status.pnl >= 0 ? 'text-success' : 'text-destructive'">
        {{ money(status.pnl, currency, true) }} · {{ status.trades }} trade
      </span>
    </div>

    <p v-if="!status.has_rules" class="mt-2 text-xs text-muted-foreground">
      Belum ada aturan yang diisi.
      <Link href="/rules" class="text-gold underline underline-offset-2">Tulis aturan trading kamu</Link>
      supaya sisa jatah loss harian tampil di sini.
    </p>

    <div v-else class="mt-3 space-y-3">
      <div v-if="status.loss_limit">
        <div class="flex justify-between text-xs">
          <span class="text-muted-foreground">Batas loss harian</span>
          <span class="tnum font-mono">
            {{ money(status.loss_used, currency) }} / {{ money(status.loss_limit, currency) }}
          </span>
        </div>
        <div class="mt-1 h-1.5 overflow-hidden rounded-full bg-muted">
          <div
            class="h-full rounded-full transition-all"
            :class="status.loss_breached ? 'bg-destructive' : lossPct > 60 ? 'bg-gold' : 'bg-muted-foreground'"
            :style="{ width: `${lossPct}%` }"
          />
        </div>
        <p class="mt-1 text-[11px]" :class="status.loss_breached ? 'text-destructive' : 'text-muted-foreground'">
          <template v-if="status.loss_breached">Batas loss hari ini sudah terlampaui — waktunya berhenti.</template>
          <template v-else>Sisa {{ money(status.loss_limit - status.loss_used, currency) }}.</template>
        </p>
      </div>

      <div v-if="status.profit_goal">
        <div class="flex justify-between text-xs">
          <span class="text-muted-foreground">Target profit harian</span>
          <span class="tnum font-mono">{{ money(status.pnl, currency) }} / {{ money(status.profit_goal, currency) }}</span>
        </div>
        <div class="mt-1 h-1.5 overflow-hidden rounded-full bg-muted">
          <div class="h-full rounded-full bg-success transition-all" :style="{ width: `${profitPct}%` }" />
        </div>
      </div>

      <div class="flex flex-wrap gap-x-5 gap-y-1 text-[11px] text-muted-foreground">
        <span v-if="status.max_trades" :class="status.trades_breached ? 'text-destructive' : ''">
          Trade: {{ status.trades }} / {{ status.max_trades }}
        </span>
        <span v-if="status.max_drawdown_pct" :class="status.drawdown_breached ? 'text-destructive' : ''">
          Drawdown: {{ pct(status.drawdown_pct) }} / {{ pct(status.max_drawdown_pct) }}
        </span>
        <span v-if="status.min_rr" :class="status.low_rr_trades ? 'text-destructive' : ''">
          RR minimum {{ num(status.min_rr) }}<template v-if="status.low_rr_trades">
            — {{ status.low_rr_trades }} trade di bawahnya</template>
        </span>
      </div>
    </div>
  </div>
</template>
