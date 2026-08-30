<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Head, router, useForm } from '@inertiajs/vue3'
import { ImageUp, Pencil, Plus, Trash2 } from '@lucide/vue'

import ConfirmDestroy from '@/components/ConfirmDestroy.vue'
import Pagination from '@/components/Pagination.vue'
import StatCard from '@/components/StatCard.vue'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useBackClose } from '@/composables/useBackClose'
import { longDate, money, monthLabel, price, rateCurrency, toIdr, useCurrency } from '@/composables/useFormat'
import type { Paginated } from '@/types'

interface Row {
  id: string
  type: 'deposit' | 'withdrawal'
  amount: number
  rate_idr: number | null
  occurred_at: string
  note: string | null
  has_proof: boolean
}

const props = defineProps<{
  filters: { year: number | null; month: number | null }
  years: number[]
  items: Paginated<Row>
  totals: {
    deposit: number
    withdrawal: number
    deposit_idr: number
    withdrawal_idr: number
    balance: number
    initial_balance: number
  }
}>()

const currency = useCurrency()
const open = ref(false)

/**
 * Filter periode. Bawaannya bulan berjalan; `ALL` yang eksplisit membuka
 * seluruh riwayat. Bulan hanya berarti kalau tahunnya juga dipilih — "Agustus"
 * lintas tahun bukan angka yang berarti, jadi memilih semua tahun ikut
 * mengunci bulannya ke semua.
 */
const ALL = 'all'

const MONTHS = Array.from({ length: 12 }, (_, i) => ({
  value: String(i + 1),
  label: monthLabel(`2000-${String(i + 1).padStart(2, '0')}`).split(' ')[0],
}))

function filterBy(year: string, month: string) {
  router.get(
    '/transactions',
    { year, month: year === ALL ? ALL : month },
    { preserveScroll: true, preserveState: true },
  )
}

const year = computed(() => (props.filters.year === null ? ALL : String(props.filters.year)))
const month = computed(() => (props.filters.month === null ? ALL : String(props.filters.month)))

const scopeLabel = computed(() => {
  if (!props.filters.year) return 'sepanjang waktu'

  return props.filters.month
    ? monthLabel(`${props.filters.year}-${String(props.filters.month).padStart(2, '0')}`)
    : String(props.filters.year)
})

// Akun rupiah tidak perlu kurs — nilainya sudah rupiah.
const needsRate = computed(() => currency.value !== 'IDR')

// Bukti transfer dibaca di sini, bukan di tab baru: gambarnya kecil dan
// tab baru selalu berarti kehilangan tempat di daftar.
const viewing = ref<Row | null>(null)

useBackClose(viewing)

const inIdr = (row: Row) => toIdr(row.amount, row.rate_idr, currency.value)

// Uang sungguhan: hapus hanya lewat konfirmasi berkode, bukan confirm() browser.
const removing = ref<Row | null>(null)

function destroy() {
  router.delete(`/transactions/${removing.value!.id}`, {
    preserveScroll: true,
    onFinish: () => (removing.value = null),
  })
}

const form = useForm({
  // Withdrawal jadi bawaan: setoran hanya sesekali di awal, penarikan yang rutin dicatat.
  type: 'withdrawal' as 'deposit' | 'withdrawal',
  amount: null as number | null,
  rate_idr: null as number | null,
  occurred_at: new Date().toISOString().slice(0, 10),
  proof: null as File | null,
  note: '',
})

const proofPreview = ref<string | null>(null)

/** Baris yang sedang diperbaiki; null berarti dialognya mencatat yang baru. */
const editing = ref<Row | null>(null)

function pickProof(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0] ?? null

  if (proofPreview.value) URL.revokeObjectURL(proofPreview.value)

  form.proof = file
  proofPreview.value = file ? URL.createObjectURL(file) : null
}

function edit(row: Row) {
  form.defaults({
    type: row.type,
    amount: row.amount,
    rate_idr: row.rate_idr,
    occurred_at: row.occurred_at,
    proof: null,
    note: row.note ?? '',
  })
  form.reset()
  form.clearErrors()

  if (proofPreview.value) URL.revokeObjectURL(proofPreview.value)
  proofPreview.value = null

  editing.value = row
  open.value = true
}

/** Tutup dialog: bawaan form dikembalikan ke "catat baru" apa pun jalannya. */
watch(open, (value) => {
  if (value) return

  editing.value = null
  form.defaults({
    type: 'withdrawal',
    amount: null,
    rate_idr: null,
    occurred_at: new Date().toISOString().slice(0, 10),
    proof: null,
    note: '',
  })
  form.reset()
  form.clearErrors()

  if (proofPreview.value) URL.revokeObjectURL(proofPreview.value)
  proofPreview.value = null
})

function submit() {
  form.post(editing.value ? `/transactions/${editing.value.id}` : '/transactions', {
    preserveScroll: true,
    onSuccess: () => (open.value = false),
  })
}
</script>

<template>
  <Head title="Dana" />

  <div class="space-y-5">
    <div class="flex items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-semibold">Deposit & withdrawal</h1>
        <p class="text-sm text-muted-foreground">Arus dana masuk-keluar, terpisah dari hasil trading.</p>
      </div>
      <Button class="gap-1.5" @click="open = true"><Plus class="size-4" /> Catat</Button>
    </div>

    <div class="flex flex-wrap items-center gap-2">
      <Select :model-value="year" @update:model-value="(value) => filterBy(String(value), month)">
        <SelectTrigger class="h-9 w-36" aria-label="Tahun"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem :value="ALL">Semua tahun</SelectItem>
          <SelectItem v-for="item in years" :key="item" :value="String(item)">{{ item }}</SelectItem>
        </SelectContent>
      </Select>

      <Select
        :model-value="month"
        :disabled="year === ALL"
        @update:model-value="(value) => filterBy(year, String(value))"
      >
        <SelectTrigger class="h-9 w-36" aria-label="Bulan"><SelectValue /></SelectTrigger>
        <SelectContent>
          <SelectItem :value="ALL">Semua bulan</SelectItem>
          <SelectItem v-for="item in MONTHS" :key="item.value" :value="item.value">{{ item.label }}</SelectItem>
        </SelectContent>
      </Select>
    </div>

    <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <StatCard label="Saldo sekarang" :value="money(totals.balance, currency)" tone="gold" />
      <StatCard label="Modal awal" :value="money(totals.initial_balance, currency)" />
      <StatCard
        :label="`Deposit · ${scopeLabel}`"
        :value="money(totals.deposit, currency)"
        :hint="needsRate ? money(totals.deposit_idr, 'IDR') : null"
        tone="good"
      />
      <StatCard
        :label="`Withdrawal · ${scopeLabel}`"
        :value="money(totals.withdrawal, currency)"
        :hint="needsRate ? money(totals.withdrawal_idr, 'IDR') : null"
        tone="bad"
      />
    </div>

    <div class="grid gap-2 lg:hidden">
      <p v-if="!items.data.length" class="glass-card p-8 text-center text-sm text-muted-foreground">
        {{ filters.year ? `Tidak ada transaksi pada ${scopeLabel}.` : 'Belum ada transaksi.' }}
      </p>

      <div v-for="row in items.data" :key="row.id" class="glass-card flex items-center gap-3 p-3">
        <button v-if="row.has_proof" type="button" class="shrink-0" @click="viewing = row">
          <img :src="`/transactions/${row.id}/proof`" alt="Bukti transfer" class="size-10 rounded border object-cover" />
        </button>
        <span v-else class="grid size-10 shrink-0 place-items-center rounded border text-xs text-muted-foreground">—</span>

        <div class="min-w-0 flex-1">
          <p class="truncate text-sm" :class="row.type === 'deposit' ? 'text-success' : 'text-destructive'">
            {{ row.type === 'deposit' ? 'Deposit' : 'Withdrawal' }}
          </p>
          <p class="truncate text-[11px] text-muted-foreground">
            {{ longDate(row.occurred_at) }}<template v-if="row.note"> · {{ row.note }}</template>
          </p>
        </div>

        <div class="shrink-0 text-right">
          <p class="tnum font-mono text-sm" :class="row.type === 'deposit' ? 'text-success' : 'text-destructive'">
            {{ money(row.type === 'deposit' ? row.amount : -row.amount, currency, true) }}
          </p>
          <p v-if="needsRate" class="tnum font-mono text-[11px] text-muted-foreground">
            {{ money(inIdr(row), 'IDR') }}
            <span v-if="row.rate_idr" class="opacity-70">@ {{ price(row.rate_idr) }}</span>
          </p>
        </div>

        <Button size="icon-xs" variant="ghost" class="shrink-0" title="Ubah" @click="edit(row)">
          <Pencil class="size-3.5" />
        </Button>
        <Button size="icon-xs" variant="ghost" class="shrink-0" title="Hapus" @click="removing = row">
          <Trash2 class="size-3.5 text-destructive" />
        </Button>
      </div>
    </div>

    <div class="glass-card table-scroll hidden overflow-x-auto lg:block">
      <table class="w-full min-w-[36rem] text-sm">
        <thead class="border-b text-left text-[11px] uppercase tracking-wide text-muted-foreground">
          <tr>
            <th class="p-3 font-medium">Tanggal</th>
            <th class="p-3 font-medium">Jenis</th>
            <th class="p-3 font-medium">Bukti</th>
            <th class="p-3 font-medium">Catatan</th>
            <th class="p-3 text-right font-medium">Jumlah</th>
            <th v-if="needsRate" class="p-3 text-right font-medium">Rupiah</th>
            <th class="p-3" />
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-if="!items.data.length">
            <td :colspan="needsRate ? 7 : 6" class="p-10 text-center text-muted-foreground">
              {{ filters.year ? `Tidak ada transaksi pada ${scopeLabel}.` : 'Belum ada transaksi.' }}
            </td>
          </tr>
          <tr v-for="row in items.data" :key="row.id" class="hover:bg-accent/40">
            <td class="p-3 text-xs whitespace-nowrap">{{ longDate(row.occurred_at) }}</td>
            <td class="p-3">
              <span :class="row.type === 'deposit' ? 'text-success' : 'text-destructive'">
                {{ row.type === 'deposit' ? 'Deposit' : 'Withdrawal' }}
              </span>
            </td>
            <td class="p-3">
              <button v-if="row.has_proof" type="button" class="inline-block" @click="viewing = row">
                <img
                  :src="`/transactions/${row.id}/proof`"
                  alt="Bukti transfer"
                  class="size-9 rounded border object-cover transition-opacity hover:opacity-80"
                />
              </button>
              <span v-else class="text-xs text-muted-foreground">—</span>
            </td>
            <td class="p-3 text-xs text-muted-foreground">{{ row.note || '—' }}</td>
            <td class="tnum p-3 text-right font-mono" :class="row.type === 'deposit' ? 'text-success' : 'text-destructive'">
              {{ money(row.type === 'deposit' ? row.amount : -row.amount, currency, true) }}
            </td>
            <td v-if="needsRate" class="tnum p-3 text-right font-mono text-xs text-muted-foreground">
              {{ money(inIdr(row), 'IDR') }}
              <span v-if="row.rate_idr" class="block text-[11px] opacity-70">
                @ {{ price(row.rate_idr) }}/{{ rateCurrency(currency) }}
              </span>
            </td>
            <td class="p-3 text-right">
              <Button size="icon-xs" variant="ghost" title="Ubah" @click="edit(row)">
                <Pencil class="size-3.5" />
              </Button>
              <Button size="icon-xs" variant="ghost" title="Hapus" @click="removing = row">
                <Trash2 class="size-3.5 text-destructive" />
              </Button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <Pagination :meta="items" label="transaksi" />

    <ConfirmDestroy
      :open="removing !== null"
      :title="removing?.type === 'withdrawal' ? 'Hapus withdrawal ini?' : 'Hapus deposit ini?'"
      :description="`${money(removing?.amount, currency)} pada ${longDate(removing?.occurred_at)} beserta bukti transfernya dihapus permanen, dan saldo akun ikut berubah.`"
      confirm-label="Hapus transaksi"
      @update:open="(value) => !value && (removing = null)"
      @confirm="destroy"
    />

    <Dialog :open="viewing !== null" @update:open="(value) => !value && (viewing = null)">
      <DialogContent class="h-dvh w-screen max-w-none gap-0 rounded-none border-0 p-3 sm:max-w-none">
        <DialogHeader class="sr-only">
          <DialogTitle>Bukti transfer</DialogTitle>
        </DialogHeader>
        <img
          v-if="viewing"
          :src="`/transactions/${viewing.id}/proof`"
          alt="Bukti transfer"
          class="size-full object-contain"
        />
      </DialogContent>
    </Dialog>

    <Dialog v-model:open="open">
      <DialogContent class="sm:max-w-sm">
        <DialogHeader>
          <DialogTitle>{{ editing ? 'Ubah transaksi' : 'Catat transaksi' }}</DialogTitle>
        </DialogHeader>

        <form class="space-y-4" @submit.prevent="submit">
          <div class="flex rounded-md border p-0.5">
            <button
              v-for="type in (['deposit', 'withdrawal'] as const)"
              :key="type"
              type="button"
              class="flex-1 rounded px-2 py-1 text-sm transition-colors"
              :class="
                form.type === type
                  ? type === 'deposit'
                    ? 'bg-success/20 text-success'
                    : 'bg-destructive/20 text-destructive'
                  : 'text-muted-foreground'
              "
              @click="form.type = type"
            >
              {{ type === 'deposit' ? 'Deposit' : 'Withdrawal' }}
            </button>
          </div>

          <div class="space-y-2">
            <Label for="amount">Jumlah ({{ currency }})</Label>
            <Input id="amount" v-model="form.amount" type="number" step="0.01" min="0" placeholder="500" required />
            <p v-if="form.errors.amount" class="text-xs text-destructive">{{ form.errors.amount }}</p>
          </div>

          <div v-if="needsRate" class="space-y-2">
            <Label for="rate_idr">Kurs rupiah (1 {{ rateCurrency(currency) }} = Rp …)</Label>
            <Input id="rate_idr" v-model="form.rate_idr" type="number" step="0.01" min="0" placeholder="16250" required />
            <p v-if="form.amount && form.rate_idr" class="text-xs text-muted-foreground">
              Setara <span class="tnum font-mono">{{ money(toIdr(form.amount, form.rate_idr, currency), 'IDR') }}</span>
            </p>
            <p v-if="form.errors.rate_idr" class="text-xs text-destructive">{{ form.errors.rate_idr }}</p>
          </div>

          <div class="space-y-2">
            <Label for="occurred_at">Tanggal</Label>
            <Input id="occurred_at" v-model="form.occurred_at" type="date" placeholder="Tanggal transaksi" required />
          </div>

          <div class="space-y-2">
            <Label for="proof">Bukti transfer <span v-if="!editing" class="text-gold">*</span></Label>
            <label
              class="flex cursor-pointer flex-col items-center gap-1.5 rounded-md border border-dashed p-4 text-center transition-colors hover:border-gold/50"
            >
              <input id="proof" type="file" accept="image/*" class="hidden" :required="!editing" @change="pickProof" />
              <img v-if="proofPreview" :src="proofPreview" alt="" class="max-h-40 rounded object-contain" />
              <img
                v-else-if="editing?.has_proof"
                :src="`/transactions/${editing.id}/proof`"
                alt="Bukti transfer yang tersimpan"
                class="max-h-40 rounded object-contain"
              />
              <template v-else>
                <ImageUp class="size-5 text-muted-foreground" />
                <span class="text-xs">Pilih tangkapan layar mutasi</span>
              </template>
            </label>
            <p v-if="editing" class="text-xs text-muted-foreground">
              Biarkan apa adanya kalau buktinya tidak berubah.
            </p>
            <p v-if="form.errors.proof" class="text-xs text-destructive">{{ form.errors.proof }}</p>
          </div>

          <div class="space-y-2">
            <Label for="note">Catatan</Label>
            <Input id="note" v-model="form.note" placeholder="Top up bulanan" maxlength="255" />
          </div>

          <div class="flex justify-end gap-2">
            <Button type="button" variant="ghost" @click="open = false">Batal</Button>
            <Button type="submit" :disabled="form.processing || (!editing && !form.proof)">Simpan</Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  </div>
</template>
