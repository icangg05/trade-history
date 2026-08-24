<script setup lang="ts">
import { ref } from 'vue'
import { ImageUp, LoaderCircle, Sparkles, TriangleAlert } from '@lucide/vue'

import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'

const emit = defineEmits<{
  applied: [
    payload: {
      data: Record<string, unknown>
      low_confidence_fields: string[]
      raw: Record<string, unknown> | null
      preview: string | null
    },
  ]
}>()

const open = ref(false)
const busy = ref(false)
const error = ref<string | null>(null)
const preview = ref<string | null>(null)
const file = ref<File | null>(null)

function pick(selected: File | null | undefined) {
  error.value = null

  if (!selected) return
  if (!selected.type.startsWith('image/')) {
    error.value = 'Berkas harus berupa gambar.'
    return
  }

  if (preview.value) URL.revokeObjectURL(preview.value)

  file.value = selected
  preview.value = URL.createObjectURL(selected)
}

function onDrop(event: DragEvent) {
  pick(event.dataTransfer?.files?.[0])
}

function onPaste(event: ClipboardEvent) {
  pick(Array.from(event.clipboardData?.files ?? [])[0])
}

/** Laravel menerima token CSRF terenkripsi lewat header X-XSRF-TOKEN. */
function csrf(): string {
  const match = document.cookie.match(/(?:^|;\s*)XSRF-TOKEN=([^;]+)/)

  return match ? decodeURIComponent(match[1]) : ''
}

async function submit() {
  if (!file.value || busy.value) return

  busy.value = true
  error.value = null

  const body = new FormData()
  body.append('screenshot', file.value)

  try {
    const response = await fetch('/trades/extract', {
      method: 'POST',
      body,
      headers: { Accept: 'application/json', 'X-XSRF-TOKEN': csrf() },
    })

    const payload = await response.json()

    // Gambar bukan screenshot trading, atau datanya tidak lengkap: dialog tetap
    // terbuka dengan alasannya, tidak ada field yang diisi setengah-setengah.
    if (!response.ok) {
      error.value = payload.error ?? payload.message ?? 'Gagal membaca gambar.'
      return
    }

    emit('applied', {
      data: payload.data ?? {},
      low_confidence_fields: payload.low_confidence_fields ?? [],
      raw: payload.raw ?? null,
      preview: preview.value,
    })

    close(false)
  } catch {
    error.value = 'Tidak bisa terhubung ke server.'
  } finally {
    busy.value = false
  }
}

/** `keepPreview` dipakai saat berhasil: form induk masih memakai object URL-nya. */
function close(revoke = true) {
  if (revoke && preview.value) URL.revokeObjectURL(preview.value)

  open.value = false
  file.value = null
  if (revoke) preview.value = null
  error.value = null
}
</script>

<template>
  <!-- Selama `busy` dialog dikunci: menutup di tengah jalan hanya membuang
       permintaan yang kuotanya sudah terlanjur terpakai. -->
  <Dialog :open="open" @update:open="(value) => (value ? (open = true) : !busy && close())">
    <DialogTrigger as-child>
      <Button type="button" variant="outline" class="gap-2">
        <Sparkles class="size-4 text-gold" />
        Isi dari screenshot
      </Button>
    </DialogTrigger>

    <DialogContent
      class="sm:max-w-lg"
      :show-close-button="!busy"
      @escape-key-down="busy && $event.preventDefault()"
      @interact-outside="busy && $event.preventDefault()"
    >
      <DialogHeader>
        <DialogTitle>Baca screenshot dengan AI</DialogTitle>
        <DialogDescription>
          Unggah layar posisi atau riwayat order yang memuat entry, SL, dan TP.
          Hasilnya mengisi form, periksa dulu sebelum disimpan.
        </DialogDescription>
      </DialogHeader>

      <label
        class="flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed p-6 text-center transition-colors"
        :class="busy ? 'pointer-events-none opacity-60' : 'cursor-pointer hover:border-gold/50'"
        @drop.prevent="onDrop"
        @dragover.prevent
        @paste="onPaste"
      >
        <input
          type="file"
          accept="image/*"
          class="hidden"
          :disabled="busy"
          @change="pick(($event.target as HTMLInputElement).files?.[0])"
        />

        <img v-if="preview" :src="preview" alt="" class="max-h-56 rounded-md object-contain" />
        <template v-else>
          <ImageUp class="size-7 text-muted-foreground" />
          <p class="text-sm">Klik, jatuhkan, atau tempel gambar di sini</p>
          <p class="text-xs text-muted-foreground">PNG / JPG / WEBP, maksimal 8 MB</p>
        </template>
      </label>

      <p
        v-if="error"
        class="flex items-start gap-2 rounded-md border border-destructive/40 bg-destructive/10 p-2.5 text-xs text-destructive"
      >
        <TriangleAlert class="mt-0.5 size-3.5 shrink-0" />
        {{ error }}
      </p>

      <p class="text-[11px] text-muted-foreground">
        <template v-if="busy">Jangan tutup jendela ini, permintaan sedang berjalan.</template>
        <template v-else>Gambar hanya dibaca sekali dan tidak ikut tersimpan.</template>
      </p>

      <div class="flex justify-end gap-2">
        <Button type="button" variant="ghost" :disabled="busy" @click="close()">Batal</Button>
        <Button type="button" :disabled="!file || busy" class="gap-2" @click="submit">
          <LoaderCircle v-if="busy" class="size-4 animate-spin" />
          {{ busy ? 'Membaca gambar…' : 'Baca dengan AI' }}
        </Button>
      </div>
    </DialogContent>
  </Dialog>
</template>
