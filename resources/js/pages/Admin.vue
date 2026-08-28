<script setup lang="ts">
import { onUnmounted, ref } from 'vue'
import { Head, router, useForm } from '@inertiajs/vue3'
import { DatabaseBackup, Download, KeyRound, Pencil, Plus, ShieldCheck, Trash2, X, Zap } from '@lucide/vue'

import ConfirmDestroy from '@/components/ConfirmDestroy.vue'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { dateTime, longDate } from '@/composables/useFormat'

interface Row {
  id: number
  name: string
  email: string
  is_admin: boolean
  accounts_count: number
  created_at: string
  is_self: boolean
}

interface GeminiKey {
  id: number
  name: string
  preview: string
}

interface Backup {
  name: string
  size: string
  created_at: string
}

defineProps<{
  users: Row[]
  geminiKeys: GeminiKey[]
  backups: Backup[]
}>()

const backingUp = ref(false)

const open = ref(false)
const editing = ref<Row | null>(null)
const removing = ref<Row | null>(null)
const removingKey = ref<GeminiKey | null>(null)

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

// mysqldump butuh beberapa detik; halaman di-refresh sendiri supaya berkas
// baru langsung muncul di daftar.
function createBackup() {
  backingUp.value = true
  router.post('/admin/backup', {}, {
    preserveScroll: true,
    onFinish: () => (backingUp.value = false),
  })
}

function destroyKey() {
  router.delete(`/admin/gemini-keys/${removingKey.value!.id}`, {
    preserveScroll: true,
    onFinish: () => (removingKey.value = null),
  })
}

function destroyUser() {
  router.delete(`/admin/users/${removing.value!.id}`, {
    preserveScroll: true,
    onFinish: () => (removing.value = null),
  })
}

const gemini = useForm({ name: '', api_key: '' })
const testing = ref<number | null>(null)
// Hasil uji menempel di baris kuncinya. Yang bertema jeda punya `until` dan
// hilang sendiri saat hitungan mundurnya habis; sisanya menunggu tombol tutup.
const results = ref<Record<number, { text: string; ok: boolean; until?: number }>>({})
const now = ref(Date.now())
let ticker: ReturnType<typeof setInterval> | undefined

function secondsLeft(until: number): number {
  return Math.max(0, Math.ceil((until - now.value) / 1000))
}

function tick() {
  now.value = Date.now()

  for (const [id, result] of Object.entries(results.value)) {
    if (result.until && secondsLeft(result.until) === 0) delete results.value[Number(id)]
  }

  if (!Object.values(results.value).some((result) => result.until)) {
    clearInterval(ticker)
    ticker = undefined
  }
}

onUnmounted(() => clearInterval(ticker))

function addKey() {
  gemini.post('/admin/gemini-keys', { preserveScroll: true, onSuccess: () => gemini.reset() })
}

/** Laravel menerima token CSRF terenkripsi lewat header X-XSRF-TOKEN. */
function csrf(): string {
  const match = document.cookie.match(/(?:^|;\s*)XSRF-TOKEN=([^;]+)/)

  return match ? decodeURIComponent(match[1]) : ''
}

function closeResult(id: number) {
  delete results.value[id]
}

async function testKey(id: number) {
  testing.value = id
  delete results.value[id]

  try {
    const response = await fetch(`/admin/gemini-keys/${id}/test`, {
      method: 'POST',
      headers: { Accept: 'application/json', 'X-XSRF-TOKEN': csrf() },
    })
    const payload = await response.json()

    results.value[id] = {
      text: payload.message ?? 'Gagal menguji kunci.',
      ok: response.ok,
      until: payload.retry_after ? Date.now() + payload.retry_after * 1000 : undefined,
    }

    now.value = Date.now()
    ticker ??= setInterval(tick, 250)
  } catch {
    results.value[id] = { text: 'Tidak bisa terhubung ke server.', ok: false }
  } finally {
    testing.value = null
  }
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
            Tersimpan terenkripsi di database dan dipakai semua pengguna. Kunci dipakai bergantian:
            satu kunci baru boleh dipakai lagi setelah 10 detik. Tanpa kunci, fitur AI (import
            screenshot dan analisa) tidak bisa dipakai.
          </p>
        </div>
      </div>

      <div v-if="geminiKeys.length" class="divide-y rounded-md border">
        <div v-for="row in geminiKeys" :key="row.id" class="flex flex-wrap items-center gap-3 p-2.5">
          <div class="min-w-0 shrink-0">
            <p class="truncate text-sm font-medium">{{ row.name }}</p>
            <p class="truncate font-mono text-[11px] text-muted-foreground">{{ row.preview }}</p>
          </div>

          <!-- Hasil uji: mengisi ruang antara nama kunci dan tombol, dibuang saat ditutup.
               out-in = klik Tes berulang membuat hasil lama pudar dulu, baru yang baru masuk. -->
          <Transition
            mode="out-in"
            enter-active-class="animate-in fade-in slide-in-from-left-2 duration-200"
            leave-active-class="animate-out fade-out slide-out-to-left-2 duration-150"
          >
            <div
              v-if="results[row.id]"
              :key="results[row.id].text"
              class="order-last flex w-full min-w-0 flex-1 items-start gap-2 rounded-md px-2.5 py-1.5 text-xs sm:order-none sm:w-auto"
              :class="results[row.id].ok ? 'bg-gold/10 text-foreground' : 'bg-destructive/10 text-destructive'"
            >
              <p class="min-w-0 flex-1 break-words">
                {{ results[row.id].text }}
                <template v-if="results[row.id].until">
                  Tunggu {{ secondsLeft(results[row.id].until!) }} detik lagi.
                </template>
              </p>
              <button
                type="button"
                title="Tutup"
                class="shrink-0 text-muted-foreground hover:text-foreground"
                @click="closeResult(row.id)"
              >
                <X class="size-3.5" />
              </button>
            </div>
          </Transition>

          <div class="ml-auto flex shrink-0 gap-1">
            <Button size="sm" variant="outline" class="gap-1.5" :disabled="testing === row.id" @click="testKey(row.id)">
              <Zap class="size-3.5" />
              {{ testing === row.id ? 'Menguji…' : 'Tes' }}
            </Button>
            <Button size="icon-xs" variant="ghost" title="Hapus" @click="removingKey = row">
              <Trash2 class="size-3.5 text-destructive" />
            </Button>
          </div>
        </div>
      </div>
      <p v-else class="text-xs text-muted-foreground">Belum ada kunci — import AI dan analisa nonaktif.</p>

      <form class="grid gap-3 sm:grid-cols-[1fr_2fr_auto]" @submit.prevent="addKey">
        <div class="space-y-1.5">
          <Label for="key_name">Nama kunci</Label>
          <Input id="key_name" v-model="gemini.name" placeholder="Akun utama" required />
          <p v-if="gemini.errors.name" class="text-xs text-destructive">{{ gemini.errors.name }}</p>
        </div>
        <div class="space-y-1.5">
          <Label for="api_key">Kunci API</Label>
          <Input id="api_key" v-model="gemini.api_key" type="password" autocomplete="off" placeholder="AIza… (tempel kunci di sini)" required />
          <p v-if="gemini.errors.api_key" class="text-xs text-destructive">{{ gemini.errors.api_key }}</p>
        </div>
        <div class="flex items-end">
          <Button type="submit" class="w-full gap-1.5" :disabled="gemini.processing">
            <Plus class="size-4" /> Tambah
          </Button>
        </div>
      </form>
    </div>

    <!-- ------------------------------------------------------------ Backup -->
    <div class="glass-card space-y-3 p-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div class="flex items-start gap-2">
          <DatabaseBackup class="mt-0.5 size-4 shrink-0 text-gold" />
          <div>
            <h2 class="text-sm font-semibold">Cadangan database</h2>
            <p class="text-xs text-muted-foreground">
              Seluruh isi database — pengguna, akun, trade, transaksi, aturan — dalam berkas <code>.sql</code> (berkas bukti transfer di <code>storage/app</code> tidak termasuk).
              Dibuat otomatis tiap Minggu pukul 03.00; hanya 4 yang terbaru disimpan.
            </p>
          </div>
        </div>
        <Button variant="outline" size="sm" class="gap-1.5" :disabled="backingUp" @click="createBackup">
          <DatabaseBackup class="size-4" />
          {{ backingUp ? 'Membuat…' : 'Buat sekarang' }}
        </Button>
      </div>

      <div v-if="backups.length" class="divide-y rounded-md border">
        <div v-for="file in backups" :key="file.name" class="flex flex-wrap items-center justify-between gap-3 p-2.5">
          <div class="min-w-0">
            <p class="truncate font-mono text-xs">{{ file.name }}</p>
            <p class="text-[11px] text-muted-foreground">{{ dateTime(file.created_at) }} · {{ file.size }}</p>
          </div>
          <a :href="`/admin/backup/${file.name}`" download class="shrink-0">
            <Button size="sm" variant="ghost" class="gap-1.5">
              <Download class="size-3.5" /> Unduh
            </Button>
          </a>
        </div>
      </div>
      <p v-else class="text-xs text-muted-foreground">Belum ada cadangan tersimpan.</p>
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
      :open="removingKey !== null"
      :title="`Hapus kunci ${removingKey?.name ?? ''}?`"
      description="Kunci ini tidak lagi dipakai untuk memanggil Gemini. Kunci lain tetap jalan."
      confirm-label="Hapus kunci"
      @update:open="(value) => !value && (removingKey = null)"
      @confirm="destroyKey"
    />

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
