<script setup lang="ts">
import { ref } from 'vue'
import { Head, useForm } from '@inertiajs/vue3'
import { Eye, Pencil } from '@lucide/vue'

import Markdown from '@/components/Markdown.vue'
import RuleStatusBanner from '@/components/RuleStatusBanner.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { useCurrency } from '@/composables/useFormat'
import type { RuleStatus } from '@/types'

const props = defineProps<{
  rule: {
    max_daily_loss: number | null
    max_daily_loss_pct: number | null
    daily_profit_target: number | null
    daily_profit_target_pct: number | null
    max_total_loss_pct: number | null
    max_risk_per_trade_pct: number | null
    max_trades_per_day: number | null
    min_rr: number | null
    allowed_sessions: string[]
    notes: string
  }
  status: RuleStatus
}>()

const currency = useCurrency()
const preview = ref(false)

const SESSIONS = [
  { key: 'sydney', label: 'Sydney' },
  { key: 'tokyo', label: 'Tokyo' },
  { key: 'london', label: 'London' },
  { key: 'newyork', label: 'New York' },
]

const form = useForm({ ...props.rule })

function toggleSession(key: string) {
  form.allowed_sessions = form.allowed_sessions.includes(key)
    ? form.allowed_sessions.filter((s) => s !== key)
    : [...form.allowed_sessions, key]
}
</script>

<template>
  <Head title="Aturan" />

  <div class="space-y-4">
    <div>
      <h1 class="text-xl font-semibold">Aturan trading</h1>
      <p class="text-sm text-muted-foreground">
        Catatan pribadi untuk mengingat batasan sendiri. Tidak ada satu pun angka di sini yang
        memblokir pencatatan trade — hanya dipakai untuk menghitung sisa jatah dan menandai
        hari yang melanggar.
      </p>
    </div>

    <form class="grid gap-4 lg:grid-cols-3" @submit.prevent="form.put('/rules')">
      <div class="space-y-4 lg:col-span-2">
        <div class="glass-card space-y-4 p-4">
          <h2 class="text-sm font-semibold">Batas harian</h2>

          <div class="grid gap-3 sm:grid-cols-2">
            <div class="space-y-1.5">
              <Label for="max_daily_loss">Maks. loss harian ({{ currency }})</Label>
              <Input id="max_daily_loss" v-model="form.max_daily_loss" type="number" step="0.01" min="0" placeholder="Contoh: 100" />
            </div>
            <div class="space-y-1.5">
              <Label for="max_daily_loss_pct">…atau dalam persen saldo</Label>
              <Input
                id="max_daily_loss_pct"
                v-model="form.max_daily_loss_pct"
                type="number"
                step="0.1"
                min="0"
                max="100"
                placeholder="Contoh: 2"
              />
            </div>
            <div class="space-y-1.5">
              <Label for="daily_profit_target">Target profit harian ({{ currency }})</Label>
              <Input
                id="daily_profit_target"
                v-model="form.daily_profit_target"
                type="number"
                step="0.01"
                min="0"
                placeholder="Contoh: 150"
              />
            </div>
            <div class="space-y-1.5">
              <Label for="daily_profit_target_pct">…atau dalam persen saldo</Label>
              <Input
                id="daily_profit_target_pct"
                v-model="form.daily_profit_target_pct"
                type="number"
                step="0.1"
                min="0"
                max="100"
                placeholder="Contoh: 3"
              />
            </div>
          </div>

          <p class="text-[11px] text-muted-foreground">
            Kalau keduanya diisi, nilai nominal yang dipakai. Persentase dihitung dari saldo
            pembukaan hari itu.
          </p>
        </div>

        <div class="glass-card space-y-4 p-4">
          <h2 class="text-sm font-semibold">Batas per trade & keseluruhan</h2>

          <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <div class="space-y-1.5">
              <Label for="max_risk_per_trade_pct">Risiko / trade (%)</Label>
              <Input
                id="max_risk_per_trade_pct"
                v-model="form.max_risk_per_trade_pct"
                type="number"
                step="0.1"
                min="0"
                max="100"
                placeholder="Contoh: 1"
              />
            </div>
            <div class="space-y-1.5">
              <Label for="min_rr">RR minimum</Label>
              <Input id="min_rr" v-model="form.min_rr" type="number" step="0.1" min="0" placeholder="Contoh: 2" />
            </div>
            <div class="space-y-1.5">
              <Label for="max_trades_per_day">Maks. trade / hari</Label>
              <Input id="max_trades_per_day" v-model="form.max_trades_per_day" type="number" min="1" placeholder="Contoh: 3" />
            </div>
            <div class="space-y-1.5">
              <Label for="max_total_loss_pct">Maks. drawdown (%)</Label>
              <Input
                id="max_total_loss_pct"
                v-model="form.max_total_loss_pct"
                type="number"
                step="0.1"
                min="0"
                max="100"
                placeholder="Contoh: 10"
              />
            </div>
          </div>

          <div class="space-y-2">
            <Label>Sesi yang boleh ditradingkan</Label>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="session in SESSIONS"
                :key="session.key"
                type="button"
                class="rounded-full border px-3 py-1 text-xs transition-colors"
                :class="
                  form.allowed_sessions.includes(session.key)
                    ? 'border-gold/50 bg-gold/15 text-gold'
                    : 'text-muted-foreground hover:text-foreground'
                "
                @click="toggleSession(session.key)"
              >
                {{ session.label }}
              </button>
            </div>
          </div>
        </div>

        <div class="glass-card space-y-3 p-4">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-semibold">Catatan aturan</h2>
            <Button type="button" variant="ghost" size="sm" class="gap-1.5" @click="preview = !preview">
              <component :is="preview ? Pencil : Eye" class="size-3.5" />
              {{ preview ? 'Ubah' : 'Pratinjau' }}
            </Button>
          </div>

          <Markdown v-if="preview" :source="form.notes || '_Belum ada catatan._'" />
          <Textarea
            v-else
            v-model="form.notes"
            rows="14"
            class="font-mono text-xs"
            placeholder="## Checklist sebelum entry&#10;- [ ] Cek kalender news&#10;- [ ] Konfirmasi struktur H4&#10;&#10;## Pantangan&#10;- Tidak entry setelah 2 loss beruntun&#10;- Tidak balas dendam"
          />
          <p class="text-[11px] text-muted-foreground">Mendukung markdown.</p>
        </div>

        <div class="flex justify-end">
          <Button type="submit" :disabled="form.processing">Simpan aturan</Button>
        </div>
      </div>

      <div class="h-fit lg:sticky lg:top-20">
        <RuleStatusBanner :status="status" :currency="currency" />
      </div>
    </form>
  </div>
</template>
