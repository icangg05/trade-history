<script setup lang="ts">
import { Head, Link, useForm } from '@inertiajs/vue3'
import { LoaderCircle } from '@lucide/vue'
import { onUnmounted, ref, watch } from 'vue'

import AuthShell from '@/components/AuthShell.vue'
import PasswordInput from '@/components/PasswordInput.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const props = defineProps<{ canRegister: boolean; lockedFor: number }>()

const form = useForm({ email: '', password: '', remember: false })

// Komponennya tetap terpasang saat server menolak dan mengirim ulang
// lockedFor, jadi jam-nya di-restart lewat watch, bukan sekali saat mount.
const sisaKunci = ref(0)
let timer: ReturnType<typeof setInterval> | undefined

watch(
  () => props.lockedFor,
  (detik) => {
    clearInterval(timer)
    sisaKunci.value = detik
    if (detik > 0) {
      timer = setInterval(() => {
        if (--sisaKunci.value <= 0) clearInterval(timer)
      }, 1000)
    }
  },
  { immediate: true },
)

onUnmounted(() => clearInterval(timer))
</script>

<template>
  <Head title="Masuk" />

  <AuthShell title="Masuk" subtitle="Masuk untuk melanjutkan jurnal tradingmu.">
    <form class="space-y-5" @submit.prevent="form.post('/login')">
      <div class="space-y-2">
        <Label for="email">Email</Label>
        <Input
          id="email"
          v-model="form.email"
          type="email"
          autocomplete="username"
          placeholder="nama@email.com"
          autofocus
          required
        />
        <p v-if="form.errors.email" class="text-xs text-destructive">
          {{ form.errors.email }}
          <template v-if="sisaKunci > 0">Coba lagi dalam {{ sisaKunci }} detik.</template>
        </p>
      </div>

      <div class="space-y-2">
        <Label for="password">Kata sandi</Label>
        <PasswordInput
          id="password"
          v-model="form.password"
          autocomplete="current-password"
          placeholder="Kata sandi kamu"
          required
        />
        <p v-if="form.errors.password" class="text-xs text-destructive">{{ form.errors.password }}</p>
      </div>

      <label class="flex items-center gap-2 text-sm text-muted-foreground">
        <input v-model="form.remember" type="checkbox" class="size-3.5 accent-[hsl(var(--gold))]" />
        Ingat saya
      </label>

      <Button type="submit" class="w-full gap-2" :disabled="form.processing || sisaKunci > 0">
        <LoaderCircle v-if="form.processing" class="size-4 animate-spin" />
        Masuk
      </Button>

      <p v-if="canRegister" class="border-t pt-4 text-center text-xs text-muted-foreground">
        Belum punya akun?
        <Link href="/register" class="text-gold hover:underline">Daftar</Link>
      </p>
    </form>
  </AuthShell>
</template>
