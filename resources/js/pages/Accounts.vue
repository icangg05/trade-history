<script setup lang="ts">
import { ref } from 'vue'
import { Head, router, useForm } from '@inertiajs/vue3'
import { Pencil, Plus, Trash2 } from '@lucide/vue'

import ConfirmDestroy from '@/components/ConfirmDestroy.vue'
import StatCard from '@/components/StatCard.vue'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { CURRENCIES, money, pnlClass } from '@/composables/useFormat'

interface Row {
  id: number
  name: string
  broker: string | null
  account_number: string | null
  currency: string
  is_archived: boolean
  initial_balance: number
  started_at: string
  balance: number
  net_pnl: number
  trades: number
}

interface Total {
  currency: string
  accounts: number
  balance: number
  net_pnl: number
  trades: number
}

defineProps<{ items: Row[]; totals: Total[]; activeId: number | null }>()

const open = ref(false)
const editing = ref<Row | null>(null)

const form = useForm({
  name: '',
  broker: '',
  account_number: '',
  currency: 'USD',
  initial_balance: 0,
  started_at: new Date().toISOString().slice(0, 10),
  is_archived: false,
})

function create() {
  editing.value = null
  form.reset()
  form.clearErrors()
  open.value = true
}

function edit(row: Row) {
  editing.value = row
  form.clearErrors()
  form.defaults({
    name: row.name,
    broker: row.broker ?? '',
    account_number: row.account_number ?? '',
    currency: row.currency,
    initial_balance: row.initial_balance,
    started_at: row.started_at,
    is_archived: row.is_archived,
  })
  form.reset()
  open.value = true
}

function submit() {
  const done = { onSuccess: () => (open.value = false) }

  editing.value ? form.put(`/accounts/${editing.value.id}`, done) : form.post('/accounts', done)
}

const removing = ref<Row | null>(null)

function destroy() {
  router.delete(`/accounts/${removing.value!.id}`, { onFinish: () => (removing.value = null) })
}
</script>

<template>
  <Head title="Akun" />

  <div class="space-y-5">
    <div class="flex items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-semibold">Akun trading</h1>
        <p class="text-sm text-muted-foreground">Tiap akun punya riwayat dan aturan sendiri.</p>
      </div>
      <Button class="gap-1.5" @click="create"><Plus class="size-4" /> Akun baru</Button>
    </div>

    <p v-if="!items.length" class="glass-card p-8 text-center text-sm text-muted-foreground">
      Belum ada akun. Buat satu untuk mulai mencatat trade.
    </p>

    <!-- Satu-satunya angka lintas akun di seluruh aplikasi. Dengan satu akun
         kartunya cuma mengulang kartu di bawah, jadi tidak ditampilkan. -->
    <div v-if="items.length > 1" class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <StatCard
        v-for="total in totals"
        :key="total.currency"
        :label="`Total ${total.currency}`"
        :value="money(total.balance, total.currency)"
        :hint="`${money(total.net_pnl, total.currency, true)} dari trading · ${total.trades} trade · ${total.accounts} akun`"
      />
    </div>

    <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <div
        v-for="row in items"
        :key="row.id"
        class="glass-card hover-lift p-4"
        :class="[row.id === activeId ? 'border-gold/40' : '', row.is_archived ? 'opacity-60' : '']"
      >
        <div class="flex items-start justify-between gap-2">
          <div class="min-w-0">
            <p class="truncate font-medium">{{ row.name }}</p>
            <p class="text-xs text-muted-foreground">
              {{ row.broker || 'Tanpa broker' }}<template v-if="row.account_number"> · {{ row.account_number }}</template>
              · {{ row.currency }} · {{ row.trades }} trade
            </p>
          </div>
          <span v-if="row.id === activeId" class="rounded-full bg-gold/15 px-2 py-0.5 text-[10px] text-gold">Aktif</span>
        </div>

        <p class="tnum mt-3 font-mono text-lg font-semibold">{{ money(row.balance, row.currency) }}</p>
        <p class="tnum font-mono text-xs" :class="pnlClass(row.net_pnl)">
          {{ money(row.net_pnl, row.currency, true) }} dari trading
        </p>

        <div class="mt-4 flex gap-2">
          <Button
            v-if="row.id !== activeId && !row.is_archived"
            size="sm"
            variant="outline"
            class="flex-1"
            @click="router.post(`/accounts/${row.id}/switch`)"
          >
            Buka
          </Button>
          <Button size="icon-sm" variant="ghost" title="Ubah" @click="edit(row)"><Pencil class="size-4" /></Button>
          <Button size="icon-sm" variant="ghost" title="Hapus" @click="removing = row">
            <Trash2 class="size-4 text-destructive" />
          </Button>
        </div>
      </div>
    </div>

    <ConfirmDestroy
      :open="removing !== null"
      :title="`Hapus akun ${removing?.name ?? ''}?`"
      :description="`${removing?.trades ?? 0} trade, seluruh transaksi dana, bukti transfer, aturan, dan analisa akun ini hilang permanen.`"
      confirm-label="Hapus akun"
      @update:open="(value) => !value && (removing = null)"
      @confirm="destroy"
    />

    <Dialog v-model:open="open">
      <DialogContent class="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{{ editing ? 'Ubah akun' : 'Akun baru' }}</DialogTitle>
          <DialogDescription>
            Saldo awal dan tanggal mulai jadi titik nol kurva perkembangan akun.
          </DialogDescription>
        </DialogHeader>

        <form class="space-y-4" @submit.prevent="submit">
          <div class="space-y-2">
            <Label for="name">Nama akun</Label>
            <Input id="name" v-model="form.name" placeholder="FTMO 10K" required />
            <p v-if="form.errors.name" class="text-xs text-destructive">{{ form.errors.name }}</p>
          </div>

          <div class="grid gap-3 sm:grid-cols-2">
            <div class="space-y-2">
              <Label for="broker">Broker</Label>
              <Input id="broker" v-model="form.broker" placeholder="Exness" />
            </div>
            <div class="space-y-2">
              <Label for="account_number">Nomor akun broker</Label>
              <Input id="account_number" v-model="form.account_number" placeholder="Contoh: 123456789" />
              <p class="text-[11px] text-muted-foreground">
                Dicetak di laporan tahunan. Ini yang menyambungkan laporanmu ke statement
                resmi broker saat pajak minta klarifikasi.
              </p>
              <p v-if="form.errors.account_number" class="text-xs text-destructive">
                {{ form.errors.account_number }}
              </p>
            </div>
            <div class="space-y-2">
              <Label for="currency">Mata uang</Label>
              <select
                id="currency"
                v-model="form.currency"
                class="h-9 w-full rounded-md border bg-background px-3 text-sm"
                required
              >
                <option v-for="item in CURRENCIES" :key="item.code" :value="item.code">
                  {{ item.label }}
                </option>
              </select>
              <p v-if="form.errors.currency" class="text-xs text-destructive">{{ form.errors.currency }}</p>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div class="space-y-2">
              <Label for="initial_balance">Saldo awal ({{ form.currency }})</Label>
              <Input
                id="initial_balance"
                v-model="form.initial_balance"
                type="number"
                step="0.01"
                min="0"
                placeholder="10000"
                required
              />
              <p v-if="form.errors.initial_balance" class="text-xs text-destructive">{{ form.errors.initial_balance }}</p>
            </div>
            <div class="space-y-2">
              <Label for="started_at">Mulai</Label>
              <Input id="started_at" v-model="form.started_at" type="date" placeholder="Tanggal mulai" required />
            </div>
          </div>

          <label v-if="editing" class="flex items-center gap-2 text-sm text-muted-foreground">
            <input v-model="form.is_archived" type="checkbox" class="size-3.5 accent-[hsl(var(--gold))]" />
            Arsipkan akun ini
          </label>

          <div class="flex justify-end gap-2 pt-1">
            <Button type="button" variant="ghost" @click="open = false">Batal</Button>
            <Button type="submit" :disabled="form.processing">Simpan</Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  </div>
</template>
