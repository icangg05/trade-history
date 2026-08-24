<script setup lang="ts">
import { ref, watch } from 'vue'
import { TriangleAlert } from '@lucide/vue'

import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

/**
 * Konfirmasi hapus yang sengaja dibuat merepotkan: kode 4 angka acak harus
 * diketik ulang, jadi tidak ada yang terhapus karena salah pencet.
 */
const props = defineProps<{
  open: boolean
  title: string
  description?: string
  confirmLabel?: string
  processing?: boolean
}>()

const emit = defineEmits<{ 'update:open': [boolean]; confirm: [] }>()

const code = ref('')
const typed = ref('')

watch(
  () => props.open,
  (open) => {
    if (!open) return

    code.value = String(Math.floor(1000 + Math.random() * 9000))
    typed.value = ''
  },
  { immediate: true },
)
</script>

<template>
  <Dialog :open="open" @update:open="emit('update:open', $event)">
    <DialogContent class="sm:max-w-sm">
      <DialogHeader>
        <DialogTitle class="flex items-center gap-2 text-destructive">
          <TriangleAlert class="size-4 shrink-0" />
          {{ title }}
        </DialogTitle>
        <DialogDescription v-if="description">{{ description }}</DialogDescription>
      </DialogHeader>

      <form class="space-y-4" @submit.prevent="typed === code && emit('confirm')">
        <div class="space-y-2">
          <Label for="destroy_code">
            Ketik kode <span class="tnum select-none font-mono text-base font-bold tracking-[0.35em] text-gold">{{ code }}</span>
            untuk melanjutkan
          </Label>
          <Input
            id="destroy_code"
            v-model="typed"
            inputmode="numeric"
            autocomplete="off"
            maxlength="4"
            placeholder="4 angka di atas"
            class="tnum text-center font-mono tracking-[0.35em]"
          />
        </div>

        <div class="flex justify-end gap-2">
          <Button type="button" variant="ghost" @click="emit('update:open', false)">Batal</Button>
          <Button type="submit" variant="destructive" :disabled="typed !== code || processing">
            {{ confirmLabel ?? 'Hapus permanen' }}
          </Button>
        </div>
      </form>
    </DialogContent>
  </Dialog>
</template>
