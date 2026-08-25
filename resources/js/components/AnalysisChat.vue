<script setup lang="ts">
import { nextTick, onUnmounted, ref } from 'vue'
import { router, usePage } from '@inertiajs/vue3'
import { SendHorizontal, Sparkles, X } from '@lucide/vue'

import Markdown from '@/components/Markdown.vue'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Textarea } from '@/components/ui/textarea'
import type { PageProps } from '@/types'

interface Message {
  role: 'user' | 'assistant'
  text: string
  /** Huruf yang sudah tampil saat animasi ketik; undefined = tampil penuh. */
  shown?: number
}

const props = defineProps<{ period: string; enabled: boolean }>()

const SUGGESTIONS = [
  'Apa kelemahan terbesar cara trading saya?',
  'Jam dan hari mana yang paling sering merugikan?',
  'Apakah RR saya sudah masuk akal?',
  'Apa satu hal yang harus saya perbaiki minggu depan?',
]

// Kecepatan ketik: cukup pelan untuk terbaca, tapi balasan panjang tetap
// selesai dalam beberapa detik.
const CPS = 400
const MAX_SECONDS = 6

// Riwayat disimpan di browser, per akun — refresh tidak menghapus percakapan,
// dan ganti akun tidak mencampur pembahasan.
const storageKey = `ai-chat:${usePage<PageProps>().props.currentAccount?.id ?? 0}`

function load(): Message[] {
  try {
    return JSON.parse(localStorage.getItem(storageKey) ?? '[]')
  } catch {
    return []
  }
}

function persist() {
  const plain = messages.value.map(({ role, text }) => ({ role, text }))

  localStorage.setItem(storageKey, JSON.stringify(plain))
}

const messages = ref<Message[]>(load())
const draft = ref('')
const busy = ref(false)
const closing = ref(false)
const confirming = ref(false)
const error = ref<string | null>(null)
const scroller = ref<HTMLElement | null>(null)

let frame: number | undefined

/** Laravel menerima token CSRF terenkripsi lewat header X-XSRF-TOKEN. */
function csrf(): string {
  const match = document.cookie.match(/(?:^|;\s*)XSRF-TOKEN=([^;]+)/)

  return match ? decodeURIComponent(match[1]) : ''
}

function scrollDown() {
  nextTick(() => scroller.value?.scrollTo({ top: scroller.value.scrollHeight, behavior: 'smooth' }))
}

/** Ikut turun hanya kalau pembaca memang sedang di dasar percakapan. */
function stickToBottom() {
  const el = scroller.value

  if (el && el.scrollHeight - el.scrollTop - el.clientHeight < 120) el.scrollTop = el.scrollHeight
}

/**
 * Balasan dimunculkan sedikit demi sedikit mengikuti waktu nyata (rAF), bukan
 * per potongan tetap, supaya lajunya halus di layar apa pun.
 */
function typeOut(index: number) {
  const message = messages.value[index]
  const speed = Math.max(CPS, message.text.length / MAX_SECONDS)
  const start = performance.now()

  message.shown = 0

  const tick = (now: number) => {
    message.shown = Math.min(message.text.length, Math.round(((now - start) / 1000) * speed))
    stickToBottom()

    if (message.shown < message.text.length) frame = requestAnimationFrame(tick)
    else finishTyping()
  }

  frame = requestAnimationFrame(tick)
}

/** Hentikan animasi dan tampilkan sisa teks sekaligus. */
function finishTyping() {
  if (frame) cancelAnimationFrame(frame)

  frame = undefined
  messages.value.forEach((message) => (message.shown = undefined))
  persist()
}

function visible(message: Message): string {
  return message.shown === undefined ? message.text : message.text.slice(0, message.shown)
}

function clear() {
  finishTyping()
  messages.value = []
  persist()
  confirming.value = false
}

/**
 * Tutup dengan animasi dulu, lalu mundur lewat history: halaman analisa
 * dipulihkan Inertia apa adanya — tidak dimuat ulang dari server, jadi terasa
 * memang menunggu di belakang. Kalau chat dibuka langsung dari alamatnya,
 * tidak ada yang bisa dimundurkan, jadi pindah halaman seperti biasa.
 */
function close() {
  const canGoBack = window.history.length > 1

  closing.value = true
  setTimeout(
    () => (canGoBack ? window.history.back() : router.visit('/analysis', { data: { period: props.period } })),
    180,
  )
}

onUnmounted(finishTyping)

async function send(text = draft.value.trim()) {
  if (!text || busy.value || !props.enabled) return

  finishTyping()

  // Sepuluh giliran terakhir sudah cukup untuk menjaga konteks percakapan;
  // sisanya hanya menambah token tanpa menambah jawaban.
  const history = messages.value.slice(-10).map(({ role, text: turn }) => ({ role, text: turn }))

  messages.value.push({ role: 'user', text })
  draft.value = ''
  busy.value = true
  error.value = null
  persist()
  scrollDown()

  try {
    const response = await fetch('/analysis/chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'X-XSRF-TOKEN': csrf(),
      },
      body: JSON.stringify({ message: text, period: props.period, history }),
    })

    const payload = await response.json()

    if (!response.ok) {
      error.value = payload.error ?? payload.message ?? 'Gagal menghubungi AI.'
      return
    }

    messages.value.push({ role: 'assistant', text: payload.reply })
    persist()
    typeOut(messages.value.length - 1)
  } catch {
    error.value = 'Jaringan terputus sebelum jawabannya sampai. Coba lagi.'
  } finally {
    busy.value = false
    scrollDown()
  }
}
</script>

<template>
  <div
    class="flex h-[100dvh] flex-col"
    :class="
      closing
        ? 'animate-out fade-out slide-out-to-bottom-4 fill-mode-forwards duration-200'
        : 'animate-in fade-in slide-in-from-bottom-4 duration-300'
    "
  >
    <div class="flex shrink-0 items-center justify-between gap-2 border-b px-4 py-2.5 sm:px-6">
      <div class="min-w-0">
        <h1 class="text-sm font-semibold">Tanya AI</h1>
        <p class="truncate text-[11px] text-muted-foreground">Berdasarkan statistik akun ini.</p>
      </div>

      <div class="flex shrink-0 items-center gap-1">
        <Button v-if="messages.length" variant="ghost" size="sm" :disabled="busy" @click="confirming = true">
          Bersihkan
        </Button>
        <Button variant="ghost" size="icon-sm" title="Tutup chat" @click="close">
          <X class="size-4" />
        </Button>
      </div>
    </div>

    <p v-if="!enabled" class="m-4 rounded-md border border-dashed p-6 text-center text-sm text-muted-foreground">
      Kunci Gemini belum diisi. Minta admin mengisinya di halaman Admin.
    </p>

    <!-- Satu kolom selebar bacaan; garis tepinya menandai lebar chat di layar besar. -->
    <div v-else class="mx-auto flex min-h-0 w-full max-w-3xl flex-1 flex-col lg:border-x">
      <div ref="scroller" class="min-h-0 flex-1 space-y-5 overflow-y-auto px-4 py-5 sm:px-6">
        <div v-if="!messages.length" class="grid gap-2 py-10 text-center">
          <Sparkles class="mx-auto size-6 text-gold" />
          <p class="text-sm">Tanyakan apa saja soal cara kamu trading.</p>
          <div class="mt-2 flex flex-wrap justify-center gap-1.5">
            <button
              v-for="item in SUGGESTIONS"
              :key="item"
              type="button"
              class="rounded-full border px-3 py-1.5 text-[11px] text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
              @click="send(item)"
            >
              {{ item }}
            </button>
          </div>
        </div>

        <!-- Balasan AI dirender sebagai markdown dan mengalir selebar kolom;
             pertanyaan sendiri tetap berbentuk gelembung di kanan. -->
        <div
          v-for="(message, index) in messages"
          :key="index"
          class="flex animate-in fade-in slide-in-from-bottom-2 duration-300"
          :class="message.role === 'user' ? 'justify-end' : 'justify-start'"
        >
          <p v-if="message.role === 'user'" class="max-w-[85%] whitespace-pre-line rounded-2xl bg-accent px-3.5 py-2 text-sm">
            {{ message.text }}
          </p>
          <Markdown v-else class="w-full" :source="visible(message)" />
        </div>

        <div v-if="busy" class="flex items-center gap-1.5 text-muted-foreground">
          <span class="size-1.5 animate-bounce rounded-full bg-gold" />
          <span class="size-1.5 animate-bounce rounded-full bg-gold [animation-delay:150ms]" />
          <span class="size-1.5 animate-bounce rounded-full bg-gold [animation-delay:300ms]" />
        </div>
      </div>

      <div class="shrink-0 border-t px-4 pt-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))] sm:px-6">
        <p v-if="error" class="mb-2 rounded-md border border-destructive/40 p-2 text-xs text-destructive">
          {{ error }}
        </p>

        <form class="flex items-end gap-2" @submit.prevent="send()">
          <Textarea
            v-model="draft"
            rows="1"
            maxlength="2000"
            placeholder="Tulis pertanyaanmu…"
            class="max-h-32 min-h-10 flex-1 resize-none rounded-2xl py-2.5"
            :disabled="busy"
            @keydown.enter.exact.prevent="send()"
          />
          <Button type="submit" size="icon" class="rounded-full" :disabled="busy || !draft.trim()" title="Kirim">
            <SendHorizontal class="size-4" />
          </Button>
        </form>

        <p class="mt-2 text-center text-[10px] text-muted-foreground">
          Percakapan disimpan di perangkat ini saja. Bukan saran finansial.
        </p>
      </div>
    </div>

    <Dialog v-model:open="confirming">
      <DialogContent class="sm:max-w-sm">
        <DialogHeader>
          <DialogTitle>Bersihkan percakapan?</DialogTitle>
          <DialogDescription>
            Semua pertanyaan dan jawaban di layar ini dihapus dari perangkatmu. Tidak bisa dikembalikan.
          </DialogDescription>
        </DialogHeader>

        <div class="flex justify-end gap-2">
          <Button variant="ghost" @click="confirming = false">Batal</Button>
          <Button variant="destructive" @click="clear">Bersihkan</Button>
        </div>
      </DialogContent>
    </Dialog>
  </div>
</template>
