<script setup lang="ts">
import { Head, Link, useForm } from '@inertiajs/vue3'
import { LoaderCircle } from '@lucide/vue'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const form = useForm({ name: '', email: '', password: '', password_confirmation: '', token: '' })
</script>

<template>
  <Head title="Daftar" />

  <div class="relative flex min-h-screen items-center justify-center p-4">
    <div class="bg-ornaments" aria-hidden="true">
      <div class="bg-grid" />
      <div class="blob blob-a" />
      <div class="blob blob-b" />
    </div>

    <form class="glass-card w-full max-w-sm space-y-5 p-6" @submit.prevent="form.post('/register')">
      <div class="space-y-1">
        <div class="mb-3 grid size-9 place-items-center rounded-lg bg-gold text-sm font-bold text-gold-foreground">
          TH
        </div>
        <h1 class="text-lg font-semibold">Buat akun</h1>
        <p class="text-sm text-muted-foreground">Jurnal trading pribadi kamu sendiri.</p>
      </div>

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

      <div class="space-y-2">
        <Label for="password">Kata sandi</Label>
        <Input
          id="password"
          v-model="form.password"
          type="password"
          autocomplete="new-password"
          placeholder="Minimal 8 karakter"
          required
        />
        <p v-if="form.errors.password" class="text-xs text-destructive">{{ form.errors.password }}</p>
      </div>

      <div class="space-y-2">
        <Label for="password_confirmation">Ulangi kata sandi</Label>
        <Input
          id="password_confirmation"
          v-model="form.password_confirmation"
          type="password"
          autocomplete="new-password"
          placeholder="Ketik ulang kata sandi"
          required
        />
      </div>

      <div class="space-y-2">
        <Label for="token">Token pendaftaran</Label>
        <Input id="token" v-model="form.token" autocomplete="off" placeholder="Token dari pemilik aplikasi" required />
        <p v-if="form.errors.token" class="text-xs text-destructive">{{ form.errors.token }}</p>
      </div>

      <Button type="submit" class="w-full gap-2" :disabled="form.processing">
        <LoaderCircle v-if="form.processing" class="size-4 animate-spin" />
        Daftar
      </Button>

      <p class="text-center text-xs text-muted-foreground">
        Sudah punya akun?
        <Link href="/login" class="text-gold hover:underline">Masuk</Link>
      </p>
    </form>
  </div>
</template>
