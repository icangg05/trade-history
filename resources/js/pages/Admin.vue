<script setup lang="ts">
import { ref } from 'vue'
import { Head, router, useForm } from '@inertiajs/vue3'
import { DatabaseBackup, KeyRound, Pencil, Plus, ShieldCheck, Trash2 } from '@lucide/vue'

import ConfirmDestroy from '@/components/ConfirmDestroy.vue'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { longDate } from '@/composables/useFormat'

interface Row {
  id: number
  name: string
  email: string
  is_admin: boolean
  accounts_count: number
  created_at: string
  is_self: boolean
}

const props = defineProps<{
  users: Row[]
  gemini: { key_preview: string | null; model: string; rpm: number; tpm: number; rpd: number }
}>()

const open = ref(false)
const editing = ref<Row | null>(null)
const removing = ref<Row | null>(null)

const user = useForm({
  name: '',
  email: '',
  password: '',
  password_confirmation: '',
  is_admin: false,
})

function create() {
  editing.value = null
  user.defaults({ name: '', email: '', password: '', password_confirmation: '', is_admin: false })
  user.reset()
  user.clearErrors()
  open.value = true
}

function edit(row: Row) {
  editing.value = row
  user.defaults({
    name: row.name,
    email: row.email,
    password: '',
    password_confirmation: '',
    is_admin: row.is_admin,
  })
  user.reset()
  user.clearErrors()
  open.value = true
}

function submitUser() {
  const done = { preserveScroll: true, onSuccess: () => (open.value = false) }

  editing.value ? user.put(`/admin/users/${editing.value.id}`, done) : user.post('/admin/users', done)
}

function destroyUser() {
  router.delete(`/admin/users/${removing.value!.id}`, {
    preserveScroll: true,
    onFinish: () => (removing.value = null),
  })
}

const gemini = useForm({
  api_key: '',
  model: props.gemini.model,
  rpm: props.gemini.rpm,
  tpm: props.gemini.tpm,
  rpd: props.gemini.rpd,
})

function saveGemini() {
  gemini.put('/admin/gemini', { preserveScroll: true, onSuccess: () => (gemini.api_key = '') })
}
</script>

<template>
  <Head title="Admin" />

  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-semibold">Admin</h1>
      <p class="text-sm text-muted-foreground">Pengguna aplikasi dan kunci Gemini yang dipakai bersama.</p>
    </div>

    <!-- ------------------------------------------------------------ Gemini -->
    <div class="glass-card space-y-4 p-4">
      <div class="flex items-start gap-2">
        <KeyRound class="mt-0.5 size-4 shrink-0 text-gold" />
        <div>
          <h2 class="text-sm font-semibold">Kunci Gemini</h2>
          <p class="text-xs text-muted-foreground">
            Tersimpan terenkripsi di database dan dipakai semua pengguna. Kosong → aplikasi memakai
            <code>GEMINI_API_KEY</code> di <code>.env</code>.
          </p>
        </div>
      </div>

      <form class="grid gap-3 sm:grid-cols-2" @submit.prevent="saveGemini">
        <div class="space-y-1.5">
          <Label for="api_key">Kunci API</Label>
          <Input
            id="api_key"
            v-model="gemini.api_key"
            type="password"
            autocomplete="off"
            :placeholder="props.gemini.key_preview ?? 'AIza… (tempel kunci di sini)'"
          />
          <p class="text-[11px] text-muted-foreground">
            <template v-if="props.gemini.key_preview">
              Terpasang: <span class="font-mono">{{ props.gemini.key_preview }}</span
              >. Kosongkan bila tidak diganti.
            </template>
            <template v-else>Belum ada kunci — import AI dan analisa nonaktif.</template>
          </p>
          <p v-if="gemini.errors.api_key" class="text-xs text-destructive">{{ gemini.errors.api_key }}</p>
        </div>

        <div class="space-y-1.5">
          <Label for="model">Nama model</Label>
          <Input id="model" v-model="gemini.model" placeholder="gemini-3.5-flash-lite" list="gemini-models" />
          <datalist id="gemini-models">
            <option value="gemini-3.5-flash" />
            <option value="gemini-3.5-flash-lite" />
            <option value="gemini-3-pro" />
          </datalist>
          <p class="text-[11px] text-muted-foreground">Sesuaikan batas di bawah kalau model diganti.</p>
          <p v-if="gemini.errors.model" class="text-xs text-destructive">{{ gemini.errors.model }}</p>
        </div>

        <div class="grid gap-3 sm:col-span-2 sm:grid-cols-3">
          <div class="space-y-1.5">
            <Label for="rpm">Permintaan / menit</Label>
            <Input id="rpm" v-model="gemini.rpm" type="number" min="1" placeholder="15" />
            <p v-if="gemini.errors.rpm" class="text-xs text-destructive">{{ gemini.errors.rpm }}</p>
          </div>
          <div class="space-y-1.5">
            <Label for="tpm">Token / menit</Label>
            <Input id="tpm" v-model="gemini.tpm" type="number" min="1000" step="1000" placeholder="250000" />
            <p v-if="gemini.errors.tpm" class="text-xs text-destructive">{{ gemini.errors.tpm }}</p>
          </div>
          <div class="space-y-1.5">
            <Label for="rpd">Permintaan / hari</Label>
            <Input id="rpd" v-model="gemini.rpd" type="number" min="1" placeholder="500" />
            <p v-if="gemini.errors.rpd" class="text-xs text-destructive">{{ gemini.errors.rpd }}</p>
          </div>
        </div>

        <p class="text-[11px] text-muted-foreground sm:col-span-2">
          Permintaan ditolak di sisi aplikasi begitu salah satu batas ini terpakai habis, jadi
          Google tidak pernah sempat mengembalikan 429. Isi sedikit di bawah kuota resmi model.
        </p>

        <div class="flex justify-end gap-2 sm:col-span-2">
          <Button
            v-if="props.gemini.key_preview"
            type="button"
            variant="ghost"
            size="sm"
            @click="router.delete('/admin/gemini', { preserveScroll: true })"
          >
            Hapus kunci
          </Button>
          <Button type="submit" :disabled="gemini.processing">Simpan</Button>
        </div>
      </form>
    </div>

    <!-- ------------------------------------------------------------ Backup -->
    <div class="glass-card flex flex-wrap items-center justify-between gap-3 p-4">
      <div class="flex items-start gap-2">
        <DatabaseBackup class="mt-0.5 size-4 shrink-0 text-gold" />
        <div>
          <h2 class="text-sm font-semibold">Cadangan database</h2>
          <p class="text-xs text-muted-foreground">
            Unduh seluruh isi database sebagai berkas <code>.sql</code> — pengguna, akun, trade,
            transaksi, dan aturan. Bukti transfer tidak ikut (berkasnya ada di
            <code>storage/app</code>).
          </p>
        </div>
      </div>
      <a href="/admin/backup" download>
        <Button variant="outline" size="sm" class="gap-1.5">
          <DatabaseBackup class="size-4" />
          Unduh .sql
        </Button>
      </a>
    </div>

    <!-- ----------------------------------------------------------- Pengguna -->
    <div class="flex items-center justify-between gap-3">
      <h2 class="text-sm font-semibold">Pengguna ({{ users.length }})</h2>
      <Button size="sm" class="gap-1.5" @click="create"><Plus class="size-4" /> Pengguna baru</Button>
    </div>

    <div class="grid gap-2 sm:hidden">
      <div v-for="row in users" :key="row.id" class="glass-card space-y-2 p-3">
        <div class="flex items-start justify-between gap-2">
          <div class="min-w-0">
            <p class="flex items-center gap-1.5 truncate font-medium">
              {{ row.name }}
              <ShieldCheck v-if="row.is_admin" class="size-3.5 shrink-0 text-gold" />
            </p>
            <p class="truncate text-xs text-muted-foreground">{{ row.email }}</p>
          </div>
          <span v-if="row.is_self" class="shrink-0 rounded-full bg-gold/15 px-2 py-0.5 text-[10px] text-gold">kamu</span>
        </div>
        <div class="flex items-center justify-between gap-2">
          <p class="text-[11px] text-muted-foreground">
            {{ row.accounts_count }} akun trading · sejak {{ longDate(row.created_at) }}
          </p>
          <div class="flex gap-1">
            <Button size="icon-xs" variant="ghost" title="Ubah" @click="edit(row)"><Pencil class="size-3.5" /></Button>
            <Button v-if="!row.is_self" size="icon-xs" variant="ghost" title="Hapus" @click="removing = row">
              <Trash2 class="size-3.5 text-destructive" />
            </Button>
          </div>
        </div>
      </div>
    </div>

    <div class="glass-card hidden overflow-x-auto sm:block">
      <table class="w-full text-sm">
        <thead class="border-b text-left text-[11px] uppercase tracking-wide text-muted-foreground">
          <tr>
            <th class="p-3 font-medium">Nama</th>
            <th class="p-3 font-medium">Email</th>
            <th class="p-3 text-right font-medium">Akun</th>
            <th class="p-3 font-medium">Sejak</th>
            <th class="p-3" />
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-for="row in users" :key="row.id" class="hover:bg-accent/40">
            <td class="p-3">
              <span class="flex items-center gap-1.5 font-medium">
                {{ row.name }}
                <ShieldCheck v-if="row.is_admin" class="size-3.5 text-gold" title="Admin" />
                <span v-if="row.is_self" class="rounded-full bg-gold/15 px-1.5 text-[10px] text-gold">kamu</span>
              </span>
            </td>
            <td class="p-3 text-muted-foreground">{{ row.email }}</td>
            <td class="tnum p-3 text-right font-mono text-xs">{{ row.accounts_count }}</td>
            <td class="p-3 text-xs whitespace-nowrap text-muted-foreground">{{ longDate(row.created_at) }}</td>
            <td class="p-3">
              <div class="flex justify-end gap-1">
                <Button size="icon-xs" variant="ghost" title="Ubah" @click="edit(row)"><Pencil class="size-3.5" /></Button>
                <Button v-if="!row.is_self" size="icon-xs" variant="ghost" title="Hapus" @click="removing = row">
                  <Trash2 class="size-3.5 text-destructive" />
                </Button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <Dialog v-model:open="open">
      <DialogContent class="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{{ editing ? 'Ubah pengguna' : 'Pengguna baru' }}</DialogTitle>
          <DialogDescription>
            Tiap pengguna punya akun trading dan riwayatnya sendiri.
          </DialogDescription>
        </DialogHeader>

        <form class="space-y-4" @submit.prevent="submitUser">
          <div class="space-y-2">
            <Label for="user_name">Nama</Label>
            <Input id="user_name" v-model="user.name" placeholder="Ilmi Faizan" required />
            <p v-if="user.errors.name" class="text-xs text-destructive">{{ user.errors.name }}</p>
          </div>

          <div class="space-y-2">
            <Label for="user_email">Email</Label>
            <Input id="user_email" v-model="user.email" type="email" placeholder="trader@contoh.com" required />
            <p v-if="user.errors.email" class="text-xs text-destructive">{{ user.errors.email }}</p>
          </div>

          <div class="grid gap-3 sm:grid-cols-2">
            <div class="space-y-2">
              <Label for="user_password">Kata sandi</Label>
              <Input
                id="user_password"
                v-model="user.password"
                type="password"
                autocomplete="new-password"
                :placeholder="editing ? 'Kosongkan bila tidak diganti' : 'Minimal 8 karakter'"
                :required="!editing"
              />
              <p v-if="user.errors.password" class="text-xs text-destructive">{{ user.errors.password }}</p>
            </div>
            <div class="space-y-2">
              <Label for="user_password_confirmation">Ulangi sandi</Label>
              <Input
                id="user_password_confirmation"
                v-model="user.password_confirmation"
                type="password"
                autocomplete="new-password"
                placeholder="Ketik ulang kata sandi"
                :required="!editing"
              />
            </div>
          </div>

          <label class="flex items-center gap-2 text-sm text-muted-foreground">
            <input v-model="user.is_admin" type="checkbox" class="size-3.5 accent-[hsl(var(--gold))]" />
            Admin — bisa membuka halaman ini
          </label>

          <div class="flex justify-end gap-2">
            <Button type="button" variant="ghost" @click="open = false">Batal</Button>
            <Button type="submit" :disabled="user.processing">Simpan</Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>

    <ConfirmDestroy
      :open="removing !== null"
      :title="`Hapus ${removing?.name ?? ''}?`"
      :description="`Seluruh akun trading, trade, transaksi, bukti, dan analisa milik ${removing?.email ?? ''} ikut terhapus permanen.`"
      confirm-label="Hapus pengguna"
      @update:open="(value) => !value && (removing = null)"
      @confirm="destroyUser"
    />
  </div>
</template>
