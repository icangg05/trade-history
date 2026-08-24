<script setup lang="ts">
import { reactive, watch } from 'vue'
import { Head, Link, router } from '@inertiajs/vue3'
import { Pencil, Plus, Sparkles, Trash2 } from '@lucide/vue'
import { useDebounceFn } from '@vueuse/core'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { dateTime, money, num, price, useCurrency } from '@/composables/useFormat'
import type { Trade } from '@/types'

interface Paginated {
  data: Trade[]
  links: { url: string | null; label: string; active: boolean }[]
  total: number
  from: number | null
  to: number | null
}

const props = defineProps<{
  trades: Paginated
  filters: Record<string, string | null>
  symbols: string[]
}>()

const currency = useCurrency()

const filters = reactive({
  symbol: props.filters.symbol ?? '',
  status: props.filters.status ?? '',
  direction: props.filters.direction ?? '',
  from: props.filters.from ?? '',
  to: props.filters.to ?? '',
})

const apply = useDebounceFn(() => {
  router.get('/trades', Object.fromEntries(Object.entries(filters).filter(([, v]) => v)), {
    preserveState: true,
    preserveScroll: true,
    replace: true,
  })
}, 300)

watch(filters, apply)

const STATUS = {
  open: { label: 'Open', class: 'text-muted-foreground' },
  win: { label: 'Win', class: 'text-success' },
  loss: { label: 'Loss', class: 'text-destructive' },
  be: { label: 'BE', class: 'text-muted-foreground' },
}

/**
 * Stop yang sudah digeser: ditandai supaya kolom RR yang kosong punya alasan
 * yang terlihat — R memang tidak bisa dihitung lagi setelah risikonya dilepas.
 */
const STOP = {
  breakeven: { label: 'BE', title: 'Stop loss di harga entry — risiko nol, R tidak dihitung' },
  locked: { label: 'SL+', title: 'Stop loss sudah lewat entry — profit terkunci, R tidak dihitung' },
}

function stopTag(trade: Trade) {
  return trade.stop_state === 'breakeven' || trade.stop_state === 'locked' ? STOP[trade.stop_state] : null
}

function destroy(trade: Trade) {
  if (confirm(`Hapus trade ${trade.symbol}?`)) router.delete(`/trades/${trade.id}`, { preserveScroll: true })
}
</script>

<template>
  <Head title="Trade" />

  <div class="space-y-4">
    <div class="flex items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-semibold">Riwayat trade</h1>
        <p class="text-sm text-muted-foreground">{{ trades.total }} trade tercatat</p>
      </div>
      <Link href="/trades/create">
        <Button class="gap-1.5"><Plus class="size-4" /> Trade baru</Button>
      </Link>
    </div>

    <div class="glass-card grid gap-2 p-3 sm:grid-cols-2 lg:grid-cols-5">
      <Input v-model="filters.symbol" placeholder="Cari simbol — XAUUSD" list="symbols" class="h-9" />
      <datalist id="symbols">
        <option v-for="symbol in symbols" :key="symbol" :value="symbol" />
      </datalist>

      <select v-model="filters.status" class="h-9 rounded-md border bg-background px-3 text-sm">
        <option value="">Semua status</option>
        <option value="open">Open</option>
        <option value="win">Win</option>
        <option value="loss">Loss</option>
        <option value="be">Breakeven</option>
      </select>

      <select v-model="filters.direction" class="h-9 rounded-md border bg-background px-3 text-sm">
        <option value="">Buy & sell</option>
        <option value="buy">Buy</option>
        <option value="sell">Sell</option>
      </select>

      <label class="flex items-center gap-2 text-xs text-muted-foreground">
        <span class="shrink-0">Dari</span>
        <Input v-model="filters.from" type="date" class="h-9" placeholder="Tanggal awal" aria-label="Tanggal awal" />
      </label>
      <label class="flex items-center gap-2 text-xs text-muted-foreground">
        <span class="shrink-0">Sampai</span>
        <Input v-model="filters.to" type="date" class="h-9" placeholder="Tanggal akhir" aria-label="Tanggal akhir" />
      </label>
    </div>

    <!-- Ponsel: satu kartu per trade. Tabel sembilan kolom tidak akan pernah
         muat di layar selebar 360px tanpa geser ke samping. -->
    <div class="grid gap-2 lg:hidden">
      <p v-if="!trades.data.length" class="glass-card p-8 text-center text-sm text-muted-foreground">
        Tidak ada trade yang cocok.
      </p>

      <div v-for="trade in trades.data" :key="trade.id" class="glass-card space-y-2 p-3">
        <div class="flex items-start justify-between gap-2">
          <div class="min-w-0">
            <p class="flex items-center gap-1.5 font-medium">
              <span class="truncate">{{ trade.symbol }}</span>
              <Badge :variant="trade.direction === 'buy' ? 'default' : 'secondary'" class="shrink-0 text-[10px]">
                {{ trade.direction === 'buy' ? 'BUY' : 'SELL' }}
              </Badge>
              <Sparkles v-if="trade.source === 'ai'" class="size-3 shrink-0 text-gold" title="Diisi dari screenshot" />
            </p>
            <p class="truncate text-[11px] text-muted-foreground">
              {{ dateTime(trade.opened_at) }}<template v-if="trade.setup"> · {{ trade.setup }}</template>
            </p>
          </div>
          <p class="tnum shrink-0 font-mono text-sm" :class="STATUS[trade.status].class">
            {{ trade.pnl === null ? 'Open' : money(trade.pnl, currency, true) }}
          </p>
        </div>

        <div class="grid grid-cols-3 gap-2 text-[11px]">
          <div>
            <p class="text-muted-foreground">Lot</p>
            <p class="tnum font-mono">{{ num(trade.lot, 2) }}</p>
          </div>
          <div>
            <p class="text-muted-foreground">Entry</p>
            <p class="tnum font-mono">{{ price(trade.entry_price) }}</p>
          </div>
          <div>
            <p class="text-muted-foreground">RR</p>
            <p class="tnum font-mono">
              <template v-if="trade.rr_realized !== null">{{ num(trade.rr_realized) }}R</template>
              <template v-else-if="trade.rr_planned !== null">{{ num(trade.rr_planned) }}R*</template>
              <template v-else>—</template>
            </p>
          </div>
        </div>

        <div class="flex items-center justify-between gap-2 border-t pt-2">
          <p class="tnum flex min-w-0 items-center gap-1.5 truncate font-mono text-[11px] text-muted-foreground">
            <span class="truncate">SL {{ price(trade.sl_price) }} · TP {{ price(trade.tp_price) }}</span>
            <span
              v-if="stopTag(trade)"
              class="shrink-0 rounded-full bg-cyan/15 px-1.5 text-[9px] text-cyan"
              :title="stopTag(trade)!.title"
            >
              {{ stopTag(trade)!.label }}
            </span>
          </p>
          <div class="flex shrink-0 gap-1">
            <Link :href="`/trades/${trade.id}/edit`">
              <Button size="icon-xs" variant="ghost" title="Ubah"><Pencil class="size-3.5" /></Button>
            </Link>
            <Button size="icon-xs" variant="ghost" title="Hapus" @click="destroy(trade)">
              <Trash2 class="size-3.5 text-destructive" />
            </Button>
          </div>
        </div>
      </div>
    </div>

    <div class="glass-card table-scroll hidden overflow-x-auto lg:block">
      <table class="w-full min-w-[54rem] text-sm">
        <thead class="border-b text-left text-[11px] uppercase tracking-wide text-muted-foreground">
          <tr>
            <th class="p-3 font-medium">Waktu</th>
            <th class="p-3 font-medium">Simbol</th>
            <th class="p-3 font-medium">Arah</th>
            <th class="p-3 text-right font-medium">Lot</th>
            <th class="p-3 text-right font-medium">Entry</th>
            <th class="p-3 text-right font-medium">SL / TP</th>
            <th class="p-3 text-right font-medium">RR</th>
            <th class="p-3 text-right font-medium">P/L</th>
            <th class="p-3" />
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-if="!trades.data.length">
            <td colspan="9" class="p-10 text-center text-muted-foreground">Tidak ada trade yang cocok.</td>
          </tr>

          <tr v-for="trade in trades.data" :key="trade.id" class="hover:bg-accent/40">
            <td class="whitespace-nowrap p-3 text-xs text-muted-foreground">{{ dateTime(trade.opened_at) }}</td>
            <td class="p-3">
              <div class="flex items-center gap-1.5 font-medium">
                {{ trade.symbol }}
                <Sparkles v-if="trade.source === 'ai'" class="size-3 text-gold" title="Diisi dari screenshot" />
              </div>
              <span v-if="trade.setup" class="text-[11px] text-muted-foreground">{{ trade.setup }}</span>
            </td>
            <td class="p-3">
              <Badge :variant="trade.direction === 'buy' ? 'default' : 'secondary'" class="text-[10px]">
                {{ trade.direction === 'buy' ? 'BUY' : 'SELL' }}
              </Badge>
            </td>
            <td class="tnum p-3 text-right font-mono text-xs">{{ num(trade.lot, 2) }}</td>
            <td class="tnum p-3 text-right font-mono text-xs">{{ price(trade.entry_price) }}</td>
            <td class="tnum p-3 text-right font-mono text-[11px] text-muted-foreground">
              {{ price(trade.sl_price) }} / {{ price(trade.tp_price) }}
              <span
                v-if="stopTag(trade)"
                class="ml-1 rounded-full bg-cyan/15 px-1.5 text-[9px] text-cyan"
                :title="stopTag(trade)!.title"
              >
                {{ stopTag(trade)!.label }}
              </span>
            </td>
            <td class="p-3 text-right">
              <!-- Posisi yang kena SL/TP persis membuat R hasil sama dengan R rencana
                   (atau tepat −1,00R). Rencananya ikut ditampilkan supaya barisnya
                   tetap bercerita, bukan sekadar mengulang angka yang sama. -->
              <span v-if="trade.rr_realized !== null" class="tnum font-mono text-xs">
                {{ num(trade.rr_realized) }}R
              </span>
              <span v-else-if="trade.rr_planned !== null" class="tnum font-mono text-xs text-muted-foreground">
                {{ num(trade.rr_planned) }}R*
              </span>
              <span v-else class="text-xs text-muted-foreground">—</span>

              <span
                v-if="trade.rr_realized !== null && trade.rr_planned !== null"
                class="tnum block font-mono text-[10px] text-muted-foreground"
              >
                rencana {{ num(trade.rr_planned) }}R
              </span>
            </td>
            <td class="tnum p-3 text-right font-mono text-sm" :class="STATUS[trade.status].class">
              {{ trade.pnl === null ? 'Open' : money(trade.pnl, currency, true) }}
            </td>
            <td class="p-3">
              <div class="flex justify-end gap-1">
                <Link :href="`/trades/${trade.id}/edit`">
                  <Button size="icon-xs" variant="ghost"><Pencil class="size-3.5" /></Button>
                </Link>
                <Button size="icon-xs" variant="ghost" @click="destroy(trade)">
                  <Trash2 class="size-3.5 text-destructive" />
                </Button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <p class="text-[11px] text-muted-foreground">
      RR bertanda * adalah rencana, bukan hasil. Tanda
      <span class="rounded-full bg-cyan/15 px-1.5 text-[9px] text-cyan">BE</span> berarti stop loss
      sudah dipindah ke harga entry dan
      <span class="rounded-full bg-cyan/15 px-1.5 text-[9px] text-cyan">SL+</span> berarti sudah
      melewatinya — risikonya dilepas, jadi nilai R tidak lagi bisa dihitung.
    </p>

    <div v-if="trades.links.length > 3" class="flex flex-wrap justify-center gap-1">
      <Button
        v-for="link in trades.links"
        :key="link.label"
        size="sm"
        :variant="link.active ? 'default' : 'ghost'"
        :disabled="!link.url"
        @click="link.url && router.get(link.url, {}, { preserveScroll: true })"
      >
        <span v-html="link.label" />
      </Button>
    </div>
  </div>
</template>
