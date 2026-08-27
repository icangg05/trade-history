<script setup lang="ts">
import { Head, Link, useForm } from '@inertiajs/vue3'
import { LoaderCircle } from '@lucide/vue'

import AuthShell from '@/components/AuthShell.vue'
import PasswordInput from '@/components/PasswordInput.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const form = useForm({ name: '', email: '', password: '', password_confirmation: '', token: '' })
</script>

<template>
  <Head title="Daftar" />

  <AuthShell title="Buat akun" subtitle="Buat akun untuk mulai mencatat trade.">
    <form class="space-y-4" @submit.prevent="form.post('/register')">
      <div class="grid gap-4 sm:grid-cols-2">
        <div class="space-y-2">
          <Label for="name">Nama</Label>
          <Input id="name" v-model="form.name" autocomplete="name" placeholder="Nama kamu" autofocus required />
          <p v-if="form.errors.name" class="text-xs text-destructive">{{ form.errors.name }}</p>
        </div>

        <div class="space-y-2">
          <Label for="email">Email</Label>
          <Input id="email" v-model="form.email" type="email" autocomplete="username" placeholder="nama@email.com" required />
          <p v-if="form.errors.email" class="text-xs text-destructive">{{ form.errors.email }}</p>
        </div>
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <div class="space-y-2">
          <Label for="password">Kata sandi</Label>
          <PasswordInput
            id="password"
            v-model="form.password"
            autocomplete="new-password"
            placeholder="Minimal 8 karakter"
            required
          />
          <p v-if="form.errors.password" class="text-xs text-destructive">{{ form.errors.password }}</p>
        </div>

        <div class="space-y-2">
          <Label for="password_confirmation">Ulangi</Label>
          <PasswordInput
            id="password_confirmation"
            v-model="form.password_confirmation"
            autocomplete="new-password"
            placeholder="Ketik ulang"
            required
          />
        </div>
      </div>

      <div class="space-y-2">
        <Label for="token">Token pendaftaran</Label>
        <Input id="token" v-model="form.token" autocomplete="off" placeholder="Kode undangan dari administrator" required />
        <p v-if="form.errors.token" class="text-xs text-destructive">{{ form.errors.token }}</p>
        <p v-else class="text-[11px] text-muted-foreground">
          Pendaftaran hanya lewat undangan administrator.
        </p>
      </div>

      <Button type="submit" class="w-full gap-2" :disabled="form.processing">
        <LoaderCircle v-if="form.processing" class="size-4 animate-spin" />
        Daftar
      </Button>

      <p class="border-t pt-3 text-center text-xs text-muted-foreground">
        Sudah punya akun?
        <Link href="/login" class="text-gold hover:underline">Masuk</Link>
      </p>
    </form>
  </AuthShell>
</template>
