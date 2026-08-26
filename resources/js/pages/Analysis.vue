<script setup lang="ts">
import { computed } from 'vue'
import { Head, router, useForm } from '@inertiajs/vue3'
import { LoaderCircle, MessageCircleQuestion, Sparkles } from '@lucide/vue'

import Markdown from '@/components/Markdown.vue'
import StatCard from '@/components/StatCard.vue'
import { Button } from '@/components/ui/button'
import { dateTime, longDate, money, num, pct } from '@/composables/useFormat'
import type { Breakdown, Summary } from '@/types'

const props = defineProps<{
  period: string
  summary: Summary
  aiEnabled: boolean
  model: string
  analysis: {
    result_md: string
    model: string
    analyzed_at: string
    period_start: string
    period_end: string
    stale: boolean
  } | null
}>()

const PERIODS = [
  { key: '30d', label: '30 hari' },
  { key: '90d', label: '90 hari' },
  { key: '1y', label: '1 tahun' },
  { key: 'all', label: 'Semua' },
]

const currency = computed(() => props.summary.currency)
const form = useForm({ period: props.period })

function generate() {
  form.period = props.period

  // Tanpa progress bar: permintaan ini bisa berjalan puluhan detik, dan bar
  // yang menggantung di atas halaman selama itu terbaca seperti macet.
  // Umpan baliknya dipegang tombol yang berputar dan panel di bawahnya.
  form.post('/analysis', { preserveScroll: true, showProgress: false })
}

/** Ambil beberapa baris teratas dari sebuah breakdown untuk ditampilkan. */
function top(breakdown: Breakdown, limit = 5) {
  return Object.entries(breakdown).slice(0, limit)
}
</script>

<template>
  <Head title="Analisa" />

  <div class="space-y-5">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-semibold">Analisa trading</h1>
        <p class="text-sm text-muted-foreground">
          Statistik dihitung dari database; AI hanya menafsirkan angkanya.
        </p>
      </div>

      <div class="flex items-center gap-2">
        <Button variant="outline" size="sm" class="gap-1.5" @click="router.get('/analysis/chat', { period })">
          <MessageCircleQuestion class="size-4" /> Tanya AI
        </Button>

        <div class="flex rounded-md border p-0.5">
          <button
            v-for="item in PERIODS"
            :key="item.key"
            type="button"
            class="rounded px-2 py-1 text-xs transition-colors"
            :class="period === item.key ? 'bg-accent text-accent-foreground' : 'text-muted-foreground hover:text-foreground'"
            @click="router.get('/analysis', { period: item.key }, { preserveScroll: true })"
          >
            {{ item.label }}
          </button>
        </div>
      </div>
    </div>

    <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <StatCard label="Trade" :value="String(summary.total_trades)" :hint="`${summary.open_trades} masih terbuka`" />
      <StatCard
        label="Net P/L"
        :value="money(summary.net_pnl, currency, true)"
        :tone="summary.net_pnl >= 0 ? 'good' : 'bad'"
      />
      <StatCard label="Winrate" :value="pct(summary.win_rate_pct)" :hint="`${summary.wins}W / ${summary.losses}L`" />
      <StatCard
        label="Payoff"
        :value="summary.payoff_ratio === null ? '—' : num(summary.payoff_ratio)"
        :hint="`Menang ${money(summary.avg_win, currency)} · kalah ${money(summary.avg_loss, currency)}`"
      />
    </div>

    <div class="grid gap-4 lg:grid-cols-3">
      <div class="glass-card p-4">
        <h2 class="mb-2 text-sm font-semibold">Per simbol</h2>
        <ul class="space-y-1.5 text-xs">
          <li v-for="[key, row] in top(summary.by_symbol)" :key="key" class="flex justify-between gap-2">
            <span class="truncate">{{ key }} <span class="text-muted-foreground">({{ row.trades }})</span></span>
            <span class="tnum shrink-0 font-mono" :class="row.pnl >= 0 ? 'text-success' : 'text-destructive'">
              {{ money(row.pnl, currency, true) }}
            </span>
          </li>
          <li v-if="!Object.keys(summary.by_symbol).length" class="text-muted-foreground">Belum ada data.</li>
        </ul>
      </div>

      <div class="glass-card p-4">
        <h2 class="mb-2 text-sm font-semibold">Per hari</h2>
        <ul class="space-y-1.5 text-xs">
          <li v-for="[key, row] in top(summary.by_weekday, 7)" :key="key" class="flex justify-between gap-2">
            <span class="truncate">{{ key }} <span class="text-muted-foreground">({{ row.trades }})</span></span>
            <span class="tnum shrink-0 font-mono" :class="row.pnl >= 0 ? 'text-success' : 'text-destructive'">
              {{ money(row.pnl, currency, true) }}
            </span>
          </li>
          <li v-if="!Object.keys(summary.by_weekday).length" class="text-muted-foreground">Belum ada data.</li>
        </ul>
      </div>

      <div class="glass-card p-4">
        <h2 class="mb-2 text-sm font-semibold">Angka lain</h2>
        <dl class="space-y-1.5 text-xs">
          <div class="flex justify-between"><dt class="text-muted-foreground">Profit factor</dt><dd class="tnum font-mono">{{ summary.profit_factor === null ? '—' : num(summary.profit_factor) }}</dd></div>
          <div class="flex justify-between"><dt class="text-muted-foreground">Ekspektasi / trade</dt><dd class="tnum font-mono">{{ money(summary.expectancy, currency, true) }}</dd></div>
          <div class="flex justify-between"><dt class="text-muted-foreground">Max drawdown</dt><dd class="tnum font-mono">{{ money(summary.max_drawdown.amount, currency) }} ({{ pct(summary.max_drawdown.pct) }})</dd></div>
          <div class="flex justify-between"><dt class="text-muted-foreground">Menang beruntun</dt><dd class="tnum font-mono">{{ summary.longest_win_streak }}</dd></div>
          <div class="flex justify-between"><dt class="text-muted-foreground">Kalah beruntun</dt><dd class="tnum font-mono">{{ summary.longest_loss_streak }}</dd></div>
          <div class="flex justify-between"><dt class="text-muted-foreground">RR rata-rata</dt><dd class="tnum font-mono">{{ summary.avg_rr_realized === null ? '—' : `${num(summary.avg_rr_realized)}R` }}</dd></div>
        </dl>
      </div>
    </div>

    <div class="glass-card p-4">
      <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 class="text-sm font-semibold">Analisa AI</h2>
          <p class="text-[11px] text-muted-foreground">
            Model {{ model }}. Hasil terakhir tetap tersimpan walau data berubah.
          </p>
          <p v-if="analysis" class="text-[11px]" :class="analysis.stale ? 'text-gold' : 'text-muted-foreground'">
            Terakhir dianalisa {{ dateTime(analysis.analyzed_at) }}<span v-if="analysis.stale">
              · data sudah berubah sejak itu</span>
          </p>
        </div>

        <div class="flex gap-2">
          <Button size="sm" class="gap-2" :disabled="!aiEnabled || form.processing" @click="generate()">
            <LoaderCircle v-if="form.processing" class="size-4 animate-spin" />
            <Sparkles v-else class="size-4" />
            {{ analysis ? 'Perbarui' : 'Analisa sekarang' }}
          </Button>
        </div>
      </div>

      <p v-if="!aiEnabled" class="rounded-md border border-dashed p-6 text-center text-sm text-muted-foreground">
        Kunci Gemini belum diisi. Minta admin mengisinya di halaman Admin.
      </p>

      <div
        v-else-if="form.processing"
        class="flex flex-col items-center gap-2 rounded-md border border-dashed p-8 text-center"
      >
        <LoaderCircle class="size-5 animate-spin text-gold" />
        <p class="text-sm">Sedang membaca jurnalmu…</p>
        <p class="text-[11px] text-muted-foreground">
          Analisa penuh biasanya butuh 20-60 detik. Halaman tidak perlu ditutup atau dimuat ulang.
        </p>
      </div>

      <template v-else-if="analysis">
        <Markdown :source="analysis.result_md" />
        <p class="mt-4 border-t pt-2 text-[11px] text-muted-foreground">
          Ditulis {{ analysis.model }} atas data
          {{ longDate(analysis.period_start) }} — {{ longDate(analysis.period_end) }}.
          Ini bukan saran finansial — hanya pembacaan pola dari jurnalmu sendiri.
        </p>
      </template>

      <p v-else class="rounded-md border border-dashed p-6 text-center text-sm text-muted-foreground">
        Belum ada analisa untuk periode ini.
      </p>
    </div>
  </div>
</template>
