<script setup lang="ts">
import { ref } from 'vue'
import { Head, router, useForm } from '@inertiajs/vue3'
import { ImageUp, Plus, Trash2 } from '@lucide/vue'

import ConfirmDestroy from '@/components/ConfirmDestroy.vue'
import Pagination from '@/components/Pagination.vue'
import StatCard from '@/components/StatCard.vue'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { longDate, money, useCurrency } from '@/composables/useFormat'
import type { Paginated } from '@/types'

interface Row {
  id: number
  type: 'deposit' | 'withdrawal'
  amount: number
  occurred_at: string
  note: string | null
  has_proof: boolean
}

defineProps<{
  items: Paginated<Row>
  totals: {
    deposit: number
    withdrawal: number
    balance: number
    initial_balance: number
    realised_pnl: number
  }
}>()

const currency = useCurrency()
const open = ref(false)

// Uang sungguhan: hapus hanya lewat konfirmasi berkode, bukan confirm() browser.
const removing = ref<Row | null>(null)

function destroy() {
  router.delete(`/transactions/${removing.value!.id}`, {
    preserveScroll: true,
    onFinish: () => (removing.value = null),
  })
}

const form = useForm({
  type: 'deposit' as 'deposit' | 'withdrawal',
  amount: null as number | null,
  occurred_at: new Date().toISOString().slice(0, 10),
  proof: null as File | null,
  note: '',
})

const proofPreview = ref<string | null>(null)

function pickProof(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0] ?? null

  if (proofPreview.value) URL.revokeObjectURL(proofPreview.value)

  form.proof = file
  proofPreview.value = file ? URL.createObjectURL(file) : null
}

function submit() {
  form.post('/transactions', {
    preserveScroll: true,
    onSuccess: () => {
      form.reset()
      proofPreview.value = null
      open.value = false
    },
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

    <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <StatCard label="Saldo sekarang" :value="money(totals.balance, currency)" tone="gold" />
      <StatCard label="Modal awal" :value="money(totals.initial_balance, currency)" />
      <StatCard label="Total deposit" :value="money(totals.deposit, currency)" tone="good" />
      <StatCard label="Total withdrawal" :value="money(totals.withdrawal, currency)" tone="bad" />
    </div>

    <p class="text-xs text-muted-foreground">
      Saldo = modal awal + deposit − withdrawal + hasil trading
      (<span class="tnum font-mono">{{ money(totals.realised_pnl, currency, true) }}</span>).
    </p>

    <div class="grid gap-2 lg:hidden">
      <p v-if="!items.data.length" class="glass-card p-8 text-center text-sm text-muted-foreground">
        Belum ada transaksi.
      </p>

      <div v-for="row in items.data" :key="row.id" class="glass-card flex items-center gap-3 p-3">
        <a
          v-if="row.has_proof"
          :href="`/transactions/${row.id}/proof`"
          target="_blank"
          rel="noopener"
          class="shrink-0"
        >
          <img :src="`/transactions/${row.id}/proof`" alt="Bukti transfer" class="size-10 rounded border object-cover" />
        </a>
        <span v-else class="grid size-10 shrink-0 place-items-center rounded border text-xs text-muted-foreground">—</span>

        <div class="min-w-0 flex-1">
          <p class="truncate text-sm" :class="row.type === 'deposit' ? 'text-success' : 'text-destructive'">
            {{ row.type === 'deposit' ? 'Deposit' : 'Withdrawal' }}
          </p>
          <p class="truncate text-[11px] text-muted-foreground">
            {{ longDate(row.occurred_at) }}<template v-if="row.note"> · {{ row.note }}</template>
          </p>
        </div>

        <p
          class="tnum shrink-0 font-mono text-sm"
          :class="row.type === 'deposit' ? 'text-success' : 'text-destructive'"
        >
          {{ money(row.type === 'deposit' ? row.amount : -row.amount, currency, true) }}
        </p>

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
            <th class="p-3" />
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-if="!items.data.length">
            <td colspan="6" class="p-10 text-center text-muted-foreground">Belum ada transaksi.</td>
          </tr>
          <tr v-for="row in items.data" :key="row.id" class="hover:bg-accent/40">
            <td class="p-3 text-xs whitespace-nowrap">{{ longDate(row.occurred_at) }}</td>
            <td class="p-3">
              <span :class="row.type === 'deposit' ? 'text-success' : 'text-destructive'">
                {{ row.type === 'deposit' ? 'Deposit' : 'Withdrawal' }}
              </span>
            </td>
            <td class="p-3">
              <a
                v-if="row.has_proof"
                :href="`/transactions/${row.id}/proof`"
                target="_blank"
                rel="noopener"
                class="inline-block"
              >
                <img
                  :src="`/transactions/${row.id}/proof`"
                  alt="Bukti transfer"
                  class="size-9 rounded border object-cover transition-opacity hover:opacity-80"
                />
              </a>
              <span v-else class="text-xs text-muted-foreground">—</span>
            </td>
            <td class="p-3 text-xs text-muted-foreground">{{ row.note || '—' }}</td>
            <td class="tnum p-3 text-right font-mono" :class="row.type === 'deposit' ? 'text-success' : 'text-destructive'">
              {{ money(row.type === 'deposit' ? row.amount : -row.amount, currency, true) }}
            </td>
            <td class="p-3 text-right">
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

    <Dialog v-model:open="open">
      <DialogContent class="sm:max-w-sm">
        <DialogHeader>
          <DialogTitle>Catat transaksi</DialogTitle>
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

          <div class="space-y-2">
            <Label for="occurred_at">Tanggal</Label>
            <Input id="occurred_at" v-model="form.occurred_at" type="date" placeholder="Tanggal transaksi" required />
          </div>

          <div class="space-y-2">
            <Label for="proof">Bukti transfer <span class="text-gold">*</span></Label>
            <label
              class="flex cursor-pointer flex-col items-center gap-1.5 rounded-md border border-dashed p-4 text-center transition-colors hover:border-gold/50"
            >
              <input id="proof" type="file" accept="image/*" class="hidden" required @change="pickProof" />
              <img v-if="proofPreview" :src="proofPreview" alt="" class="max-h-40 rounded object-contain" />
              <template v-else>
                <ImageUp class="size-5 text-muted-foreground" />
                <span class="text-xs">Pilih tangkapan layar mutasi</span>
              </template>
            </label>
            <p v-if="form.errors.proof" class="text-xs text-destructive">{{ form.errors.proof }}</p>
          </div>

          <div class="space-y-2">
            <Label for="note">Catatan</Label>
            <Input id="note" v-model="form.note" placeholder="Top up bulanan" maxlength="255" />
          </div>

          <div class="flex justify-end gap-2">
            <Button type="button" variant="ghost" @click="open = false">Batal</Button>
            <Button type="submit" :disabled="form.processing || !form.proof">Simpan</Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  </div>
</template>
