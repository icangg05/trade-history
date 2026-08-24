<script setup lang="ts">
import { Head, Link, useForm } from '@inertiajs/vue3'
import { LoaderCircle } from '@lucide/vue'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

defineProps<{ canRegister: boolean }>()

const form = useForm({ email: '', password: '', remember: false })
</script>

<template>
  <Head title="Masuk" />

  <div class="relative flex min-h-screen items-center justify-center p-4">
    <div class="bg-ornaments" aria-hidden="true">
      <div class="bg-grid" />
      <div class="blob blob-a" />
      <div class="blob blob-b" />
    </div>

    <form class="glass-card w-full max-w-sm space-y-5 p-6" @submit.prevent="form.post('/login')">
      <div class="space-y-1">
        <div class="mb-3 grid size-9 place-items-center rounded-lg bg-gold text-sm font-bold text-gold-foreground">
          TH
        </div>
        <h1 class="text-lg font-semibold">Trade History</h1>
        <p class="text-sm text-muted-foreground">Jurnal trading pribadi.</p>
      </div>

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
        <p v-if="form.errors.email" class="text-xs text-destructive">{{ form.errors.email }}</p>
      </div>

      <div class="space-y-2">
        <Label for="password">Kata sandi</Label>
        <Input
          id="password"
          v-model="form.password"
          type="password"
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

      <Button type="submit" class="w-full gap-2" :disabled="form.processing">
        <LoaderCircle v-if="form.processing" class="size-4 animate-spin" />
        Masuk
      </Button>

      <p v-if="canRegister" class="text-center text-xs text-muted-foreground">
        Belum punya akun?
        <Link href="/register" class="text-gold hover:underline">Daftar</Link>
      </p>
    </form>
  </div>
</template>
