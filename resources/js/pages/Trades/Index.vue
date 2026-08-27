<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { Head, Link, router, useForm } from '@inertiajs/vue3'
import { Layers, Pencil, Plus, Sparkles, Trash2 } from '@lucide/vue'
import { useDebounceFn } from '@vueuse/core'

import Pagination from '@/components/Pagination.vue'
import SetupPicker from '@/components/SetupPicker.vue'
import StopBadge from '@/components/StopBadge.vue'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { clock, dateTime, longDate, money, num, price, useCurrency } from '@/composables/useFormat'
import { frameClass, frameGap } from '@/composables/useGroupFrame'
import type { Paginated, Trade } from '@/types'

const props = defineProps<{
  trades: Paginated<Trade>
  daily: Record<string, number>
  filters: Record<string, string | null>
  symbols: string[]
}>()

const currency = useCurrency()

const filters = reactive({
  symbol: props.filters.symbol ?? '',
  status: props.filters.status ?? '',
  stop: props.filters.stop ?? '',
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

/**
 * Select-nya reka-ui menolak nilai kosong, jadi "semua" diwakili sebuah
 * sentinel yang diterjemahkan balik ke string kosong sebelum masuk filter.
 */
const ALL = 'all'

const choice = (key: 'status' | 'stop' | 'direction') =>
  computed({
    get: () => filters[key] || ALL,
    set: (value: string) => (filters[key] = value === ALL ? '' : value),
  })

const status = choice('status')
const stop = choice('stop')
const direction = choice('direction')

const STATUS = {
  win: { label: 'Win', class: 'text-success' },
  loss: { label: 'Loss', class: 'text-destructive' },
  be: { label: 'BE', class: 'text-muted-foreground' },
}

/**
 * Mode pilih: menandai beberapa trade berurutan sebagai satu ide. Tidak ada
 * baris yang hilang dan tidak ada nama grup — server menyimpan kuncinya,
 * menggabungkan setup, dan menyambung catatan anggotanya.
 *
 * Hanya trade yang bersebelahan yang boleh dipilih, jadi yang bisa dicentang
 * cuma baris tepat di atas atau di bawah pilihan sekarang.
 */
const grouping = ref(false)
const picked = ref<number[]>([])

const pickedRange = computed(() => {
  const list = props.trades.data
  const indexes = picked.value.map((id) => list.findIndex((trade) => trade.id === id))

  return indexes.length ? { first: Math.min(...indexes), last: Math.max(...indexes) } : null
})

/** Grup yang ikut tersentuh pilihan sekarang — paling banyak boleh satu. */
const pickedGroups = computed(
  () =>
    new Set(
      picked.value
        .map((id) => props.trades.data.find((row) => row.id === id)?.group_id)
        .filter(Boolean) as number[],
    ),
)

/**
 * Sebuah grup dipilih sebagai satu kesatuan: klik satu anggotanya, semua
 * anggotanya ikut. Rentang inilah yang dipakai untuk menilai kebersebelahan.
 */
function blockRange(trade: Trade): { first: number; last: number } {
  const list = props.trades.data

  if (!trade.group_id) {
    const at = list.findIndex((row) => row.id === trade.id)

    return { first: at, last: at }
  }

  const indexes = list.reduce<number[]>((acc, row, at) => (row.group_id === trade.group_id ? [...acc, at] : acc), [])

  return { first: Math.min(...indexes), last: Math.max(...indexes) }
}

function pickable(trade: Trade): boolean {
  if (!grouping.value) return false

  // Menambah anggota ke grup yang sudah ada boleh; menyentuh grup kedua tidak.
  if (trade.group_id && pickedGroups.value.size > 0 && !pickedGroups.value.has(trade.group_id)) return false

  if (!pickedRange.value) return true

  const block = blockRange(trade)
  const { first, last } = pickedRange.value

  // Boleh dicentang kalau menempel di ujung pilihan, dan boleh dilepas kalau
  // dia sendiri yang ada di ujung — supaya pilihannya tidak pernah berlubang.
  return block.last === first - 1 || block.first === last + 1 || block.first === first || block.last === last
}

function togglePick(trade: Trade) {
  if (!pickable(trade)) return

  // Anggota satu grup selalu ikut bersama-sama.
  const ids = trade.group_id
    ? props.trades.data.filter((row) => row.group_id === trade.group_id).map((row) => row.id)
    : [trade.id]

  picked.value = ids.every((id) => picked.value.includes(id))
    ? picked.value.filter((id) => !ids.includes(id))
    : [...new Set([...picked.value, ...ids])]
}

function stopGrouping() {
  grouping.value = false
  picked.value = []
}

function saveGroup() {
  router.post('/trades/group', { ids: picked.value }, { preserveScroll: true, onFinish: stopGrouping })
}

function groupSize(trade: Trade): number {
  return trade.group_id ? props.trades.data.filter((row) => row.group_id === trade.group_id).length : 0
}

/** Form setup & catatan milik grup: satu simpanan untuk semua anggotanya. */
const groupForm = useForm({ setup: '', notes: '' })

function editGroup(trade: Trade) {
  groupForm.setup = trade.setup ?? ''
  groupForm.notes = trade.notes ?? ''
}

function saveGroupDetail(trade: Trade) {
  groupForm.put(`/trades/group/${trade.group_id}`, {
    preserveScroll: true,
    onSuccess: () => (selected.value = null),
  })
}

/**
 * Hanya ujung grup yang boleh dilepas: melepas anggota tengah membuat sisanya
 * tidak lagi berurutan.
 */
function atGroupEdge(trade: Trade): boolean {
  const members = props.trades.data.filter((row) => row.group_id === trade.group_id)

  return members.length > 0 && (members[0].id === trade.id || members[members.length - 1].id === trade.id)
}

function ungroup(trade: Trade) {
  router.delete(`/trades/${trade.id}/group`, {
    preserveScroll: true,
    onSuccess: () => (selected.value = null),
  })
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
 * Harinya dihitung dari `closed_at` — trade yang dibuka kemarin tapi ditutup
 * hari ini masuk hitungan hari ini. Yang masih terbuka memakai `opened_at`.
 * P/L hariannya datang dari server, jadi tetap utuh walau harinya terpotong
 * batas halaman.
 */
const dayKey = (trade: Trade) => (trade.closed_at ?? trade.opened_at).slice(0, 10)

const rows = computed(() =>
  props.trades.data.map((trade, index, list) => {
    const key = dayKey(trade)
    const first = index === 0 || key !== dayKey(list[index - 1])

    return {
      trade,
      day: first ? longDate(key) : null,
      pnl: first ? (props.daily[key] ?? null) : null,
    }
  }),
)

/**
 * Detail satu trade untuk layar ponsel. Barisnya diringkas jadi simbol, waktu,
 * dan P/L saja — sisanya menunggu di modal ini, bukan menumpuk di daftar.
 */
const selected = ref<Trade | null>(null)

function open(trade: Trade) {
  selected.value = trade
  editGroup(trade)
}

const detail = computed(() => {
  const trade = selected.value

  if (!trade) return []

  return [
    ['Lot', num(trade.lot, 2)],
    ['Entry', price(trade.entry_price)],
    ['Stop loss', price(trade.sl_price)],
    ['Take profit', price(trade.tp_price)],
    ['Exit', price(trade.exit_price)],
    ['P/L', money(trade.pnl, currency.value, true)],
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
          @click="grouping ? stopGrouping() : (grouping = true)"
        >
          <Layers class="size-4" /> {{ grouping ? 'Batal' : 'Grouping' }}
        </Button>
        <Link href="/trades/create">
          <Button class="gap-1.5"><Plus class="size-4" /> Trade baru</Button>
        </Link>
      </div>
    </div>

    <!-- Bar mode pilih: muncul hanya selama grouping. -->
    <div v-if="grouping" class="glass-card flex flex-wrap items-center justify-between gap-2 p-3 text-sm">
      <p class="text-muted-foreground">
        Pilih trade yang berurutan — hanya baris tepat di atas atau di bawah pilihan yang bisa ikut.
        Ikutkan anggota grup yang sudah ada untuk menambah trade ke dalamnya.
        <span class="text-foreground">{{ picked.length }} dipilih.</span>
      </p>
      <Button size="sm" :disabled="picked.length < 2" @click="saveGroup">
        Grouping {{ picked.length }} trade
      </Button>
    </div>

    <div class="glass-card grid gap-2 p-3 sm:grid-cols-2 lg:grid-cols-3">
      <Input v-model="filters.symbol" placeholder="Cari simbol — XAUUSD" list="symbols" class="h-9" />
      <datalist id="symbols">
        <option v-for="symbol in symbols" :key="symbol" :value="symbol" />
      </datalist>

      <Select v-model="status">
        <SelectTrigger class="h-9 w-full" aria-label="Status"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem :value="ALL">Semua status</SelectItem>
          <SelectItem value="win">Win</SelectItem>
          <SelectItem value="loss">Loss</SelectItem>
          <SelectItem value="be">Breakeven</SelectItem>
        </SelectContent>
      </Select>

      <!-- Sumbu kedua: letak stop loss terhadap entry, bukan hasil trade-nya. -->
      <Select v-model="stop">
        <SelectTrigger class="h-9 w-full" aria-label="Posisi stop"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem :value="ALL">Semua posisi stop</SelectItem>
          <SelectItem value="risk">Stop masih berisiko</SelectItem>
          <SelectItem value="breakeven">BE — stop di harga entry</SelectItem>
          <SelectItem value="sl_plus">SL+ — profit terkunci</SelectItem>
        </SelectContent>
      </Select>

      <Select v-model="direction">
        <SelectTrigger class="h-9 w-full" aria-label="Arah"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem :value="ALL">Buy &amp; sell</SelectItem>
          <SelectItem value="buy">Buy</SelectItem>
          <SelectItem value="sell">Sell</SelectItem>
        </SelectContent>
      </Select>

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

      <!-- Daftar melebar sedikit lalu isinya dimasukkan lagi, supaya garis
           bingkai grup tidak menempel ke teks maupun ke tepi kartu. -->
      <ul v-else class="-mx-2 divide-y">
        <template v-for="(row, index) in rows" :key="row.trade.id">
          <li
            v-if="row.day"
            class="-mx-1 flex items-center justify-between gap-2 bg-muted/40 px-3 py-1 text-[10px] font-medium tracking-wide text-muted-foreground uppercase"
          >
            <span>{{ row.day }}</span>
            <span
              v-if="row.pnl !== null"
              class="tnum font-mono normal-case"
              :class="row.pnl > 0 ? 'text-success' : row.pnl < 0 ? 'text-destructive' : ''"
            >
              {{ money(row.pnl, currency, true) }}
            </span>
          </li>

          <li v-if="frameGap(trades.data, index)" class="mx-2 h-2 border-b-gold/40" />

          <li :class="frameClass(trades.data, index)">
            <button
              type="button"
              class="flex w-full items-center gap-2 px-2 py-2 text-left transition-colors hover:bg-accent/40"
              :class="[
                grouping && picked.includes(row.trade.id) ? 'bg-gold/10' : '',
                grouping && !pickable(row.trade) ? 'opacity-40' : '',
              ]"
              @click="grouping ? togglePick(row.trade) : open(row.trade)"
            >
              <input
                v-if="grouping"
                type="checkbox"
                class="size-4 shrink-0 accent-gold"
                :checked="picked.includes(row.trade.id)"
                :disabled="!pickable(row.trade)"
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
                <p class="flex items-center gap-1 truncate text-[10px] leading-tight text-muted-foreground">
                  <span class="tnum font-mono">{{ clock(row.trade.opened_at) }}</span>
                  <StopBadge :state="row.trade.stop_state" />
                  <span v-if="row.trade.setup" class="truncate">· {{ row.trade.setup }}</span>
                </p>
              </div>

              <span class="tnum shrink-0 font-mono text-xs" :class="STATUS[row.trade.status].class">
                {{ money(row.trade.pnl, currency, true) }}
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
            <StopBadge :state="selected.stop_state" class="ml-1" />
          </DialogDescription>
        </DialogHeader>

        <dl class="grid grid-cols-2 gap-x-3 gap-y-2 border-t pt-3 text-xs">
          <div v-for="[label, value] in detail" :key="label" class="min-w-0">
            <dt class="text-[10px] text-muted-foreground">{{ label }}</dt>
            <dd class="tnum truncate font-mono">{{ value }}</dd>
          </div>
        </dl>

        <!-- Trade bergrup: setup & catatan diisi sekali untuk seluruh anggota. -->
        <div v-if="selected.group_id" class="space-y-2 rounded-md border border-gold/40 bg-gold/5 p-3 text-xs">
          <div class="flex items-center justify-between gap-2">
            <p class="font-medium text-gold">Satu grup dengan {{ groupSize(selected) - 1 }} trade lain</p>
            <Button
              v-if="atGroupEdge(selected)"
              size="sm"
              variant="ghost"
              class="h-7 text-[11px]"
              @click="ungroup(selected)"
            >
              Keluarkan
            </Button>
            <span v-else class="text-[10px] text-muted-foreground">
              Keluarkan dari ujung grup dulu
            </span>
          </div>

          <div class="space-y-1.5">
            <p class="text-[10px] text-muted-foreground">Setup / strategi grup</p>
            <SetupPicker v-model="groupForm.setup" dense />
          </div>

          <div class="space-y-1.5">
            <p class="text-[10px] text-muted-foreground">Catatan grup</p>
            <Textarea v-model="groupForm.notes" rows="3" placeholder="Alasan entry, kondisi pasar, evaluasi…" />
          </div>

          <div class="flex justify-end">
            <Button size="sm" :disabled="groupForm.processing" @click="saveGroupDetail(selected)">
              Simpan grup
            </Button>
          </div>
        </div>

        <div v-else-if="selected.setup" class="border-t pt-3 text-xs">
          <p class="text-[10px] text-muted-foreground">Setup</p>
          <p>{{ selected.setup }}</p>
        </div>

        <div v-if="selected.notes && !selected.group_id" class="border-t pt-3 text-xs">
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

          <template v-for="(row, index) in rows" :key="row.trade.id">
            <tr v-if="row.day" class="bg-muted/40">
              <td colspan="7" class="px-3 py-1 text-[10px] font-medium tracking-wide text-muted-foreground uppercase">
                {{ row.day }}
              </td>
              <td class="tnum px-3 py-1 text-right font-mono text-[11px] font-medium">
                <span
                  v-if="row.pnl !== null"
                  :class="row.pnl > 0 ? 'text-success' : row.pnl < 0 ? 'text-destructive' : 'text-muted-foreground'"
                >
                  {{ money(row.pnl, currency, true) }}
                </span>
              </td>
              <td class="p-0" />
            </tr>

            <tr v-if="frameGap(trades.data, index)" class="h-2 border-b-gold/40">
              <td colspan="9" class="p-0" />
            </tr>

            <tr
              class="cursor-pointer hover:bg-accent/40"
              :class="[
                frameClass(trades.data, index),
                grouping && picked.includes(row.trade.id) ? 'bg-gold/10' : '',
                grouping && !pickable(row.trade) ? 'opacity-40' : '',
              ]"
              @click="grouping ? togglePick(row.trade) : open(row.trade)"
            >
              <td class="tnum whitespace-nowrap p-3 font-mono text-xs text-muted-foreground">
                <input
                  v-if="grouping"
                  type="checkbox"
                  class="mr-2 size-4 align-middle accent-gold"
                  :checked="picked.includes(row.trade.id)"
                  :disabled="!pickable(row.trade)"
                  tabindex="-1"
                />
                {{ clock(row.trade.opened_at) }}
              </td>
              <td class="p-3">
                <div class="flex items-center gap-1.5 font-medium">
                  {{ row.trade.symbol }}
                  <Sparkles v-if="row.trade.source === 'ai'" class="size-3 text-gold" title="Diisi dari screenshot" />
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
                <StopBadge :state="row.trade.stop_state" class="ml-1" />
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
                {{ money(row.trade.pnl, currency, true) }}
              </td>
              <td class="p-3" @click.stop>
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

    <p class="text-[11px] text-muted-foreground">
      RR bertanda * adalah rencana, bukan hasil. Tanda
      <span class="rounded-full bg-cyan/15 px-1.5 text-[9px] text-cyan">BE</span> berarti stop loss
      sudah dipindah ke harga entry, sedangkan
      <span class="rounded-full bg-cyan/15 px-1.5 text-[9px] text-cyan">SL+</span> berarti sudah
      melewatinya. Risikonya sudah dilepas, jadi nilai R tidak lagi bisa dihitung.
    </p>

    <Pagination :meta="trades" label="trade" />
  </div>
</template>
