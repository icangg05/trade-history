<script setup lang="ts">
import { ref } from 'vue'
import { Head, usePage, useForm } from '@inertiajs/vue3'
import { TriangleAlert } from '@lucide/vue'

import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import type { PageProps } from '@/types'

defineProps<{ accountCount: number }>()

const user = usePage<PageProps>().props.auth.user!

const profile = useForm({
  name: user.name,
  email: user.email,
  password: '',
  password_confirmation: '',
})

const confirming = ref(false)
const removal = useForm({ password: '' })

function save() {
  profile.put('/profile', {
    preserveScroll: true,
    onSuccess: () => {
      profile.password = ''
      profile.password_confirmation = ''
    },
  })
}
</script>

<template>
  <Head title="Profil" />

  <div class="mx-auto max-w-2xl space-y-4">
    <div>
      <h1 class="text-xl font-semibold">Profil</h1>
      <p class="text-sm text-muted-foreground">Data login kamu.</p>
    </div>

    <form class="glass-card space-y-4 p-4" @submit.prevent="save">
      <div class="grid gap-3 sm:grid-cols-2">
        <div class="space-y-1.5">
          <Label for="name">Nama</Label>
          <Input id="name" v-model="profile.name" placeholder="Nama kamu" required />
          <p v-if="profile.errors.name" class="text-xs text-destructive">{{ profile.errors.name }}</p>
        </div>

        <div class="space-y-1.5">
          <Label for="email">Email</Label>
          <Input id="email" v-model="profile.email" type="email" placeholder="nama@email.com" required />
          <p v-if="profile.errors.email" class="text-xs text-destructive">{{ profile.errors.email }}</p>
        </div>
      </div>

      <div class="grid gap-3 sm:grid-cols-2">
        <div class="space-y-1.5">
          <Label for="password">Kata sandi baru</Label>
          <Input
            id="password"
            v-model="profile.password"
            type="password"
            autocomplete="new-password"
            placeholder="Kosongkan bila tidak diganti"
          />
          <p v-if="profile.errors.password" class="text-xs text-destructive">{{ profile.errors.password }}</p>
        </div>

        <div class="space-y-1.5">
          <Label for="password_confirmation">Ulangi kata sandi</Label>
          <Input
            id="password_confirmation"
            v-model="profile.password_confirmation"
            type="password"
            autocomplete="new-password"
            placeholder="Ketik ulang kata sandi baru"
          />
        </div>
      </div>

      <div class="flex justify-end">
        <Button type="submit" :disabled="profile.processing">Simpan</Button>
      </div>
    </form>

    <div class="glass-card space-y-3 border-destructive/40 p-4">
      <div class="flex items-start gap-2">
        <TriangleAlert class="mt-0.5 size-4 shrink-0 text-destructive" />
        <div>
          <h2 class="text-sm font-semibold text-destructive">Hapus akun</h2>
          <p class="mt-1 text-xs text-muted-foreground">
            Menghapus akun ini juga menghapus {{ accountCount }} akun trading beserta seluruh
            trade, transaksi, bukti transfer, aturan, dan analisanya. Tidak bisa dibatalkan.
          </p>
        </div>
      </div>

      <div class="flex justify-end">
        <Button variant="destructive" size="sm" @click="confirming = true">Hapus akun saya</Button>
      </div>
    </div>

    <Dialog v-model:open="confirming">
      <DialogContent class="sm:max-w-sm">
        <DialogHeader>
          <DialogTitle>Yakin hapus akun?</DialogTitle>
          <DialogDescription>
            Semua data hilang permanen. Masukkan kata sandi untuk melanjutkan.
          </DialogDescription>
        </DialogHeader>

        <form class="space-y-4" @submit.prevent="removal.delete('/profile')">
          <div class="space-y-2">
            <Label for="confirm_password">Kata sandi</Label>
            <Input
              id="confirm_password"
              v-model="removal.password"
              type="password"
              autocomplete="current-password"
              placeholder="Kata sandi kamu sekarang"
              required
            />
            <p v-if="removal.errors.password" class="text-xs text-destructive">{{ removal.errors.password }}</p>
          </div>

          <div class="flex justify-end gap-2">
            <Button type="button" variant="ghost" @click="confirming = false">Batal</Button>
            <Button type="submit" variant="destructive" :disabled="removal.processing">
              Hapus permanen
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  </div>
</template>
