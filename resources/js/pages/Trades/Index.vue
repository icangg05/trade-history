<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { Head, Link, router } from '@inertiajs/vue3'
import { Layers, Pencil, Plus, Sparkles, Trash2 } from '@lucide/vue'
import { useDebounceFn } from '@vueuse/core'

import ConfirmDestroy from '@/components/ConfirmDestroy.vue'
import Pagination from '@/components/Pagination.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { clock, dateTime, longDate, money, num, price, useCurrency } from '@/composables/useFormat'
import type { Paginated, Trade } from '@/types'

const props = defineProps<{
  trades: Paginated<Trade>
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

function layerCount(trade: Trade): number {
  return trade.entries?.length ?? 0
}

/**
 * Mode pilih: beberapa trade yang sebenarnya satu ide berlapis digabung jadi
 * satu trade berlayer. Baris asalnya dihapus server, jadi konfirmasinya memakai
 * dialog berkode yang sama dengan hapus.
 */
const merging = ref(false)
const picked = ref<number[]>([])
const confirmMerge = ref(false)

function togglePick(trade: Trade) {
  const at = picked.value.indexOf(trade.id)

  at === -1 ? picked.value.push(trade.id) : picked.value.splice(at, 1)
}

function stopMerging() {
  merging.value = false
  picked.value = []
  confirmMerge.value = false
}

function merge() {
  router.post('/trades/merge', { ids: picked.value }, { onFinish: stopMerging })
}

function destroy(trade: Trade) {
  if (!confirm(`Hapus trade ${trade.symbol}?`)) return

  selected.value = null
  router.delete(`/trades/${trade.id}`, { preserveScroll: true })
}

/**
 * Baris siap pakai: tanggal hanya dibawa baris pertama di harinya, jadi daftar
 * yang urut mundur itu punya pembatas yang terlihat tiap ganti hari. Sisanya
 * cukup menampilkan jam.
 *
 * Urutannya `opened_at` menurun, jadi membandingkan dengan baris sebelumnya
 * sudah cukup — tidak perlu mengelompokkan ulang.
 */
const rows = computed(() => {
  const day = (trade: Trade) => trade.opened_at.slice(0, 10)

  return props.trades.data.map((trade, index, list) => ({
    trade,
    day: index === 0 || day(trade) !== day(list[index - 1]) ? longDate(trade.opened_at) : null,
  }))
})

/**
 * Detail satu trade untuk layar ponsel. Barisnya diringkas jadi simbol, waktu,
 * dan P/L saja — sisanya menunggu di modal ini, bukan menumpuk di daftar.
 */
const selected = ref<Trade | null>(null)

const detail = computed(() => {
  const trade = selected.value

  if (!trade) return []

  return [
    ['Lot', num(trade.lot, 2)],
    ['Entry', price(trade.entry_price)],
    ['Stop loss', price(trade.sl_price)],
    ['Take profit', price(trade.tp_price)],
    ['Exit', price(trade.exit_price)],
    ['P/L', trade.pnl === null ? 'Masih terbuka' : money(trade.pnl, currency.value, true)],
    ['RR rencana', trade.rr_planned === null ? '—' : `${num(trade.rr_planned)}R`],
    ['RR hasil', trade.rr_realized === null ? '—' : `${num(trade.rr_realized)}R`],
    ['Ditutup', dateTime(trade.closed_at)],
  ]
})
</script>

<template>
  <Head title="Trade" />

  <div class="space-y-4">
    <div class="flex items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-semibold">Riwayat trade</h1>
        <p class="text-sm text-muted-foreground">{{ trades.total }} trade tercatat</p>
      </div>
      <div class="flex items-center gap-2">
        <Button
          v-if="trades.data.length > 1"
          variant="outline"
          class="gap-1.5"
          @click="merging ? stopMerging() : (merging = true)"
        >
          <Layers class="size-4" /> {{ merging ? 'Batal' : 'Gabungkan' }}
        </Button>
        <Link href="/trades/create">
          <Button class="gap-1.5"><Plus class="size-4" /> Trade baru</Button>
        </Link>
      </div>
    </div>

    <!-- Bar mode pilih: muncul hanya selama menggabungkan. -->
    <div v-if="merging" class="glass-card flex flex-wrap items-center justify-between gap-2 p-3 text-sm">
      <p class="text-muted-foreground">
        Pilih trade yang sebenarnya satu ide berlapis — simbol dan arahnya harus sama.
        <span class="text-foreground">{{ picked.length }} dipilih.</span>
      </p>
      <Button size="sm" :disabled="picked.length < 2" @click="confirmMerge = true">
        Gabungkan {{ picked.length }} trade
      </Button>
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

    <!-- Ponsel: satu baris ringkas per trade, sebentuk dengan "Trade terakhir"
         di dashboard. Sembilan kolom tabel tidak akan pernah muat di layar
         360px, jadi sisa datanya menunggu di modal yang dibuka lewat baris. -->
    <div class="glass-card px-3 py-1 lg:hidden">
      <p v-if="!trades.data.length" class="py-8 text-center text-sm text-muted-foreground">
        Tidak ada trade yang cocok.
      </p>

      <ul v-else class="divide-y">
        <template v-for="row in rows" :key="row.trade.id">
          <li
            v-if="row.day"
            class="-mx-3 bg-muted/40 px-3 py-1 text-[10px] font-medium tracking-wide text-muted-foreground uppercase"
          >
            {{ row.day }}
          </li>

          <li>
            <button
              type="button"
              class="flex w-full items-center gap-2 py-2 text-left transition-colors hover:bg-accent/40"
              :class="merging && picked.includes(row.trade.id) ? 'bg-gold/10' : ''"
              @click="merging ? togglePick(row.trade) : (selected = row.trade)"
            >
              <input
                v-if="merging"
                type="checkbox"
                class="size-4 shrink-0 accent-gold"
                :checked="picked.includes(row.trade.id)"
                tabindex="-1"
              />

              <Badge
                :variant="row.trade.direction === 'buy' ? 'default' : 'secondary'"
                class="w-10 shrink-0 justify-center px-0 text-[9px]"
              >
                {{ row.trade.direction === 'buy' ? 'BUY' : 'SELL' }}
              </Badge>

              <div class="min-w-0 flex-1">
                <p class="flex items-center gap-1 text-[13px] leading-tight font-medium">
                  <span class="truncate">{{ row.trade.symbol }}</span>
                  <Sparkles
                    v-if="row.trade.source === 'ai'"
                    class="size-3 shrink-0 text-gold"
                    title="Diisi dari screenshot"
                  />
                </p>
                <p class="truncate text-[10px] leading-tight text-muted-foreground">
                  <span class="tnum font-mono">{{ clock(row.trade.opened_at) }}</span>
                  <template v-if="layerCount(row.trade) > 1"> · {{ layerCount(row.trade) }} layer</template>
                  <template v-if="row.trade.setup"> · {{ row.trade.setup }}</template>
                </p>
              </div>

              <span class="tnum shrink-0 font-mono text-xs" :class="STATUS[row.trade.status].class">
                {{ row.trade.pnl === null ? 'Open' : money(row.trade.pnl, currency, true) }}
              </span>
            </button>
          </li>
        </template>
      </ul>
    </div>

    <Dialog :open="!!selected" @update:open="(open) => open || (selected = null)">
      <DialogContent v-if="selected" class="max-h-[85vh] gap-3 overflow-y-auto p-4 sm:max-w-md">
        <DialogHeader>
          <DialogTitle class="flex items-center gap-2 pr-6 text-base">
            <span class="truncate">{{ selected.symbol }}</span>
            <Badge :variant="selected.direction === 'buy' ? 'default' : 'secondary'" class="shrink-0 text-[10px]">
              {{ selected.direction === 'buy' ? 'BUY' : 'SELL' }}
            </Badge>
            <Sparkles v-if="selected.source === 'ai'" class="size-3.5 shrink-0 text-gold" title="Diisi dari screenshot" />
          </DialogTitle>
          <DialogDescription class="text-xs" :class="STATUS[selected.status].class">
            {{ STATUS[selected.status].label }} · {{ dateTime(selected.opened_at) }}
            <span
              v-if="stopTag(selected)"
              class="ml-1 rounded-full bg-cyan/15 px-1.5 text-[9px] text-cyan"
              :title="stopTag(selected)!.title"
            >
              {{ stopTag(selected)!.label }}
            </span>
          </DialogDescription>
        </DialogHeader>

        <dl class="grid grid-cols-2 gap-x-3 gap-y-2 border-t pt-3 text-xs">
          <div v-for="[label, value] in detail" :key="label" class="min-w-0">
            <dt class="text-[10px] text-muted-foreground">{{ label }}</dt>
            <dd class="tnum truncate font-mono">{{ value }}</dd>
          </div>
        </dl>

        <div v-if="layerCount(selected) > 1" class="border-t pt-3 text-xs">
          <p class="mb-1 text-[10px] text-muted-foreground">{{ layerCount(selected) }} layer entry</p>
          <div
            v-for="(layer, index) in selected.entries"
            :key="index"
            class="tnum flex justify-between font-mono text-[11px]"
          >
            <span class="text-muted-foreground">Layer {{ index + 1 }}</span>
            <span>{{ price(layer.price) }} · {{ num(layer.lot, 2) }} lot</span>
          </div>
        </div>

        <div v-if="selected.setup" class="border-t pt-3 text-xs">
          <p class="text-[10px] text-muted-foreground">Setup</p>
          <p>{{ selected.setup }}</p>
        </div>

        <div v-if="selected.tags?.length" class="flex flex-wrap gap-1">
          <Badge v-for="tag in selected.tags" :key="tag" variant="secondary" class="text-[10px]">{{ tag }}</Badge>
        </div>

        <div v-if="selected.notes" class="border-t pt-3 text-xs">
          <p class="mb-1 text-[10px] text-muted-foreground">Catatan</p>
          <p class="whitespace-pre-line text-muted-foreground">{{ selected.notes }}</p>
        </div>

        <div class="flex justify-end gap-2 border-t pt-3">
          <Button size="sm" variant="ghost" class="gap-1.5" @click="destroy(selected)">
            <Trash2 class="size-3.5 text-destructive" /> Hapus
          </Button>
          <Link :href="`/trades/${selected.id}/edit`">
            <Button size="sm" class="gap-1.5"><Pencil class="size-3.5" /> Ubah</Button>
          </Link>
        </div>
      </DialogContent>
    </Dialog>

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

          <template v-for="row in rows" :key="row.trade.id">
            <tr v-if="row.day" class="bg-muted/40">
              <td colspan="9" class="px-3 py-1 text-[10px] font-medium tracking-wide text-muted-foreground uppercase">
                {{ row.day }}
              </td>
            </tr>

            <tr
              class="hover:bg-accent/40"
              :class="[merging ? 'cursor-pointer' : '', merging && picked.includes(row.trade.id) ? 'bg-gold/10' : '']"
              @click="merging && togglePick(row.trade)"
            >
              <td class="tnum whitespace-nowrap p-3 font-mono text-xs text-muted-foreground">
                <input
                  v-if="merging"
                  type="checkbox"
                  class="mr-2 size-4 align-middle accent-gold"
                  :checked="picked.includes(row.trade.id)"
                  tabindex="-1"
                />
                {{ clock(row.trade.opened_at) }}
              </td>
              <td class="p-3">
                <div class="flex items-center gap-1.5 font-medium">
                  {{ row.trade.symbol }}
                  <Sparkles v-if="row.trade.source === 'ai'" class="size-3 text-gold" title="Diisi dari screenshot" />
                  <Badge v-if="layerCount(row.trade) > 1" variant="secondary" class="text-[9px]">
                    {{ layerCount(row.trade) }} layer
                  </Badge>
                </div>
                <span v-if="row.trade.setup" class="text-[11px] text-muted-foreground">{{ row.trade.setup }}</span>
              </td>
              <td class="p-3">
                <Badge :variant="row.trade.direction === 'buy' ? 'default' : 'secondary'" class="text-[10px]">
                  {{ row.trade.direction === 'buy' ? 'BUY' : 'SELL' }}
                </Badge>
              </td>
              <td class="tnum p-3 text-right font-mono text-xs">{{ num(row.trade.lot, 2) }}</td>
              <td class="tnum p-3 text-right font-mono text-xs">{{ price(row.trade.entry_price) }}</td>
              <td class="tnum p-3 text-right font-mono text-[11px] text-muted-foreground">
                {{ price(row.trade.sl_price) }} / {{ price(row.trade.tp_price) }}
                <span
                  v-if="stopTag(row.trade)"
                  class="ml-1 rounded-full bg-cyan/15 px-1.5 text-[9px] text-cyan"
                  :title="stopTag(row.trade)!.title"
                >
                  {{ stopTag(row.trade)!.label }}
                </span>
              </td>
              <td class="p-3 text-right">
                <!-- Posisi yang kena SL/TP persis membuat R hasil sama dengan R rencana
                     (atau tepat −1,00R). Rencananya ikut ditampilkan supaya barisnya
                     tetap bercerita, bukan sekadar mengulang angka yang sama. -->
                <span v-if="row.trade.rr_realized !== null" class="tnum font-mono text-xs">
                  {{ num(row.trade.rr_realized) }}R
                </span>
                <span v-else-if="row.trade.rr_planned !== null" class="tnum font-mono text-xs text-muted-foreground">
                  {{ num(row.trade.rr_planned) }}R*
                </span>
                <span v-else class="text-xs text-muted-foreground">—</span>

                <span
                  v-if="row.trade.rr_realized !== null && row.trade.rr_planned !== null"
                  class="tnum block font-mono text-[10px] text-muted-foreground"
                >
                  rencana {{ num(row.trade.rr_planned) }}R
                </span>
              </td>
              <td class="tnum p-3 text-right font-mono text-sm" :class="STATUS[row.trade.status].class">
                {{ row.trade.pnl === null ? 'Open' : money(row.trade.pnl, currency, true) }}
              </td>
              <td class="p-3">
                <div class="flex justify-end gap-1">
                  <Link :href="`/trades/${row.trade.id}/edit`">
                    <Button size="icon-xs" variant="ghost"><Pencil class="size-3.5" /></Button>
                  </Link>
                  <Button size="icon-xs" variant="ghost" @click="destroy(row.trade)">
                    <Trash2 class="size-3.5 text-destructive" />
                  </Button>
                </div>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>

    <ConfirmDestroy
      :open="confirmMerge"
      :title="`Gabungkan ${picked.length} trade?`"
      description="Semuanya jadi satu trade berlayer: entry rata-rata terboboti lot, lot dan P/L dijumlah, setup serta catatan digabung. Baris aslinya dihapus permanen."
      confirm-label="Gabungkan jadi satu"
      @update:open="(value) => !value && (confirmMerge = false)"
      @confirm="merge"
    />

    <p class="text-[11px] text-muted-foreground">
      RR bertanda * adalah rencana, bukan hasil. Tanda
      <span class="rounded-full bg-cyan/15 px-1.5 text-[9px] text-cyan">BE</span> berarti stop loss
      sudah dipindah ke harga entry dan
      <span class="rounded-full bg-cyan/15 px-1.5 text-[9px] text-cyan">SL+</span> berarti sudah
      melewatinya — risikonya dilepas, jadi nilai R tidak lagi bisa dihitung.
    </p>

    <Pagination :meta="trades" label="trade" />
  </div>
</template>
