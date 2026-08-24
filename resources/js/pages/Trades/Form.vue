<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Head, Link, useForm } from '@inertiajs/vue3'
import { LoaderCircle, ShieldCheck, Sparkles } from '@lucide/vue'

import AiImportDialog from '@/components/AiImportDialog.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { num, useCurrency } from '@/composables/useFormat'
import type { Trade } from '@/types'

const props = defineProps<{
  trade: (Trade & { ai_raw: Record<string, unknown> | null }) | null
  aiEnabled: boolean
}>()

const currency = useCurrency()
const editing = computed(() => props.trade !== null)

const form = useForm({
  symbol: props.trade?.symbol ?? '',
  direction: props.trade?.direction ?? 'buy',
  lot: props.trade?.lot ?? null,
  entry_price: props.trade?.entry_price ?? null,
  sl_price: props.trade?.sl_price ?? null,
  tp_price: props.trade?.tp_price ?? null,
  exit_price: props.trade?.exit_price ?? null,
  pnl: props.trade?.pnl ?? null,
  opened_at: props.trade?.opened_at ?? new Date().toISOString().slice(0, 16),
  closed_at: props.trade?.closed_at ?? null,
  setup: props.trade?.setup ?? '',
  notes: props.trade?.notes ?? '',
  source: props.trade?.source ?? ('manual' as 'manual' | 'ai'),
  // Jejak apa yang dibaca AI dari gambar. Karena gambarnya tidak disimpan,
  // ini satu-satunya cara memeriksa ulang kalau angkanya nanti terasa janggal.
  ai_raw: (props.trade?.ai_raw ?? null) as Record<string, unknown> | null,
})

/** Field yang barusan diisi AI — ditandai supaya diperiksa dulu. */
const aiFields = ref<string[]>([])
const lowConfidence = ref<string[]>([])

// Pratinjau gambar hanya hidup di browser selama form terbuka; berkasnya tidak
// pernah dikirim ke server untuk disimpan.
const aiPreview = ref<string | null>(null)

/** RR rencana dihitung ulang di sini hanya untuk umpan balik langsung;
 *  nilai yang tersimpan tetap dihitung server. */
const plannedRr = computed(() => {
  const { entry_price: e, sl_price: sl, tp_price: tp, direction } = form

  // Hanya stop di sisi rugi yang jadi penyebut R — sama seperti hitungan server.
  if (!e || !sl || !tp) return null
  if (!(direction === 'buy' ? sl < e : sl > e)) return null

  return Math.abs(tp - e) / Math.abs(e - sl)
})

/**
 * Stop yang sudah digeser ke entry atau melewatinya bukan kesalahan — itu
 * break-even / SL+. Yang ditampilkan keterangan, bukan pesan error.
 */
const stopNote = computed(() => {
  const { entry_price: e, sl_price: sl, direction } = form

  if (!e || !sl) return null

  if (Number(sl) === Number(e)) {
    return 'Stop loss persis di harga entry — posisi break-even, risiko sudah nol. Nilai R tidak dihitung.'
  }

  const onLossSide = direction === 'buy' ? sl < e : sl > e

  if (onLossSide) return null

  return direction === 'buy'
    ? 'Stop loss di atas entry (SL+) — sebagian profit sudah dikunci, posisi tidak bisa rugi lagi. Nilai R tidak dihitung.'
    : 'Stop loss di bawah entry (SL+) — sebagian profit sudah dikunci, posisi tidak bisa rugi lagi. Nilai R tidak dihitung.'
})

const tpSideWrong = computed(() => {
  const { entry_price: e, tp_price: tp, direction } = form

  if (!e || !tp) return false

  return direction === 'buy' ? tp < e : tp > e
})

function applyAi(payload: {
  data: Record<string, unknown>
  low_confidence_fields: string[]
  raw: Record<string, unknown> | null
  preview: string | null
}) {
  const filled: string[] = []

  for (const [key, value] of Object.entries(payload.data)) {
    if (value === null || value === undefined || value === '') continue
    if (!(key in form)) continue

    ;(form as Record<string, unknown>)[key] = value
    filled.push(key)
  }

  form.source = 'ai'
  form.ai_raw = payload.raw
  aiFields.value = filled
  lowConfidence.value = payload.low_confidence_fields
  aiPreview.value = payload.preview
}

// Posisi yang punya hasil pasti punya waktu tutup: isikan otomatis (dan terlihat
// di field) supaya tidak tertahan validasi `required_with`.
watch(
  () => form.pnl,
  (pnl) => {
    if (pnl !== null && pnl !== undefined && String(pnl) !== '' && !form.closed_at) {
      form.closed_at = form.opened_at
    }
  },
)

function submit() {
  editing.value ? form.put(`/trades/${props.trade!.id}`) : form.post('/trades')
}

/**
 * Satu trade sering memakai beberapa strategi sekaligus, jadi `setup` disimpan
 * sebagai daftar dipisah koma. Nilai yang tidak ada di daftar bawaan (mis. hasil
 * baca AI atau trade lama) tetap muncul sebagai pilihan supaya tidak hilang saat
 * diedit.
 */
const SETUPS = [
  'Supply Demand',
  'Support Resisten',
  'Fibonacci',
  'Order Block',
  'FVG',
  'Parallel Channel',
  'Break of Structure',
  'CHoCH',
  'Liquidity Sweep',
  'Trendline',
  'Moving Average',
  'Breakout',
  'Pullback',
  'Pola Candlestick',
]

const selectedSetups = computed<string[]>({
  get: () => String(form.setup).split(',').map((s: string) => s.trim()).filter(Boolean),
  set: (list) => {
    form.setup = list.join(', ')
  },
})

const setupOptions = computed(() => [...new Set([...SETUPS, ...selectedSetups.value])])

function badge(field: string): string | null {
  if (lowConfidence.value.includes(field)) return 'ragu'

  return aiFields.value.includes(field) ? 'AI' : null
}
</script>

<template>
  <Head :title="editing ? 'Ubah trade' : 'Trade baru'" />

  <div class="mx-auto max-w-5xl space-y-4">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-semibold">{{ editing ? 'Ubah trade' : 'Trade baru' }}</h1>
        <p class="text-sm text-muted-foreground">
          Isi manual, atau biarkan AI membaca screenshot lalu koreksi hasilnya.
        </p>
      </div>

      <AiImportDialog v-if="aiEnabled && !editing" @applied="applyAi" />
      <p v-else-if="!aiEnabled && !editing" class="text-xs text-muted-foreground">
        Import AI nonaktif — kunci Gemini belum diisi admin.
      </p>
    </div>

    <div
      v-if="aiFields.length"
      class="glass-card flex items-start gap-2 border-gold/40 p-3 text-xs"
    >
      <Sparkles class="mt-0.5 size-4 shrink-0 text-gold" />
      <p>
        {{ aiFields.length }} field terisi dari gambar.
        <template v-if="lowConfidence.length">
          AI ragu pada: <strong>{{ lowConfidence.join(', ') }}</strong>.
        </template>
        Periksa semua angka sebelum menyimpan.
      </p>
    </div>

    <form class="grid gap-4 lg:grid-cols-3" @submit.prevent="submit">
      <div class="glass-card space-y-4 p-4" :class="aiPreview ? 'lg:col-span-2' : 'lg:col-span-3'">
        <div class="grid gap-3 sm:grid-cols-3">
          <div class="space-y-1.5">
            <Label for="symbol">Simbol <span class="text-gold">*</span></Label>
            <Input id="symbol" v-model="form.symbol" class="uppercase" placeholder="XAUUSD" required />
            <p v-if="badge('symbol')" class="text-[10px] text-gold">{{ badge('symbol') }}</p>
            <p v-if="form.errors.symbol" class="text-xs text-destructive">{{ form.errors.symbol }}</p>
          </div>

          <div class="space-y-1.5">
            <Label>Arah <span class="text-gold">*</span></Label>
            <div class="flex rounded-md border p-0.5">
              <button
                v-for="side in (['buy', 'sell'] as const)"
                :key="side"
                type="button"
                class="flex-1 rounded px-2 py-1 text-sm capitalize transition-colors"
                :class="
                  form.direction === side
                    ? side === 'buy'
                      ? 'bg-success/20 text-success'
                      : 'bg-destructive/20 text-destructive'
                    : 'text-muted-foreground'
                "
                @click="form.direction = side"
              >
                {{ side }}
              </button>
            </div>
          </div>

          <div class="space-y-1.5">
            <Label for="lot">Lot</Label>
            <Input id="lot" v-model="form.lot" type="number" step="0.01" min="0" placeholder="0.05" />
            <p v-if="badge('lot')" class="text-[10px] text-gold">{{ badge('lot') }}</p>
          </div>
        </div>

        <div class="grid gap-3 sm:grid-cols-3">
          <div class="space-y-1.5">
            <Label for="entry_price">Entry <span class="text-gold">*</span></Label>
            <Input id="entry_price" v-model="form.entry_price" type="number" step="0.00001" placeholder="2412.35" required />
            <p v-if="badge('entry_price')" class="text-[10px] text-gold">{{ badge('entry_price') }}</p>
            <p v-if="form.errors.entry_price" class="text-xs text-destructive">{{ form.errors.entry_price }}</p>
          </div>

          <div class="space-y-1.5">
            <Label for="sl_price">Stop loss</Label>
            <Input id="sl_price" v-model="form.sl_price" type="number" step="0.00001" placeholder="2405.00" />
            <p v-if="stopNote" class="flex items-start gap-1.5 text-[11px] text-cyan">
              <ShieldCheck class="mt-px size-3 shrink-0" />
              {{ stopNote }}
            </p>
            <p v-else-if="badge('sl_price')" class="text-[10px] text-gold">{{ badge('sl_price') }}</p>
            <p v-if="form.errors.sl_price" class="text-xs text-destructive">{{ form.errors.sl_price }}</p>
          </div>

          <div class="space-y-1.5">
            <Label for="tp_price">Take profit</Label>
            <Input id="tp_price" v-model="form.tp_price" type="number" step="0.00001" placeholder="2430.00" />
            <p v-if="tpSideWrong" class="text-xs text-destructive">
              TP harus di {{ form.direction === 'buy' ? 'atas' : 'bawah' }} entry.
            </p>
            <p v-else-if="badge('tp_price')" class="text-[10px] text-gold">{{ badge('tp_price') }}</p>
            <p v-if="form.errors.tp_price" class="text-xs text-destructive">{{ form.errors.tp_price }}</p>
          </div>
        </div>

        <p v-if="plannedRr" class="tnum font-mono text-xs text-muted-foreground">
          Risk/reward rencana: <span class="text-gold">{{ num(plannedRr) }}R</span>
        </p>

        <hr />

        <div class="grid gap-3 sm:grid-cols-2">
          <div class="space-y-1.5">
            <Label for="opened_at">Dibuka <span class="text-gold">*</span></Label>
            <Input id="opened_at" v-model="form.opened_at" type="datetime-local" placeholder="Tanggal & jam entry" required />
            <p v-if="form.errors.opened_at" class="text-xs text-destructive">{{ form.errors.opened_at }}</p>
          </div>

          <div class="space-y-1.5">
            <Label for="closed_at">Ditutup</Label>
            <Input
              id="closed_at"
              v-model="form.closed_at"
              type="datetime-local"
              placeholder="Kosongkan bila posisi masih open"
            />
            <p v-if="form.errors.closed_at" class="text-xs text-destructive">{{ form.errors.closed_at }}</p>
          </div>
        </div>

        <div class="grid gap-3 sm:grid-cols-2">
          <div class="space-y-1.5">
            <Label for="exit_price">Harga keluar</Label>
            <Input
              id="exit_price"
              v-model="form.exit_price"
              type="number"
              step="0.00001"
              placeholder="Kosongkan bila posisi masih open"
            />
          </div>

          <div class="space-y-1.5">
            <Label for="pnl">Hasil ({{ currency }})</Label>
            <Input id="pnl" v-model="form.pnl" type="number" step="0.01" placeholder="Kosongkan bila masih open" />
            <p v-if="form.errors.pnl" class="text-xs text-destructive">{{ form.errors.pnl }}</p>
          </div>
        </div>

        <div class="space-y-1.5">
          <Label>Setup / strategi</Label>
          <div class="flex flex-wrap gap-2">
            <label
              v-for="option in setupOptions"
              :key="option"
              class="flex cursor-pointer items-center gap-2 rounded-md border px-2.5 py-1.5 text-sm transition-colors"
              :class="
                selectedSetups.includes(option)
                  ? 'border-gold/60 bg-gold/10 text-gold'
                  : 'text-muted-foreground hover:text-foreground'
              "
            >
              <input v-model="selectedSetups" type="checkbox" :value="option" class="size-3.5 accent-gold" />
              {{ option }}
            </label>
          </div>
          <p v-if="badge('setup')" class="text-[10px] text-gold">{{ badge('setup') }}</p>
          <p v-if="form.errors.setup" class="text-xs text-destructive">{{ form.errors.setup }}</p>
        </div>

        <div class="space-y-1.5">
          <Label for="notes">Catatan</Label>
          <Textarea id="notes" v-model="form.notes" rows="4" placeholder="Kondisi pasar, alasan entry, evaluasi…" />
        </div>

        <div class="flex justify-end gap-2">
          <Link href="/trades"><Button type="button" variant="ghost">Batal</Button></Link>
          <Button type="submit" class="gap-2" :disabled="form.processing">
            <LoaderCircle v-if="form.processing" class="size-4 animate-spin" />
            Simpan
          </Button>
        </div>
      </div>

      <div v-if="aiPreview" class="glass-card h-fit space-y-2 p-4">
        <h2 class="text-sm font-semibold">Gambar sumber</h2>
        <img :src="aiPreview" alt="Screenshot yang dibaca AI" class="w-full rounded-md border object-contain" />
        <p class="text-[11px] text-muted-foreground">
          Hanya untuk mencocokkan angka. Gambar tidak disimpan dan akan hilang setelah
          form ditutup.
        </p>
      </div>
    </form>
  </div>
</template>
