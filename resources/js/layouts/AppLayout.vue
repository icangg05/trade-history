<script setup lang="ts">
import { computed, watch } from 'vue'
import { Link, router, usePage } from '@inertiajs/vue3'
import { toast, Toaster } from 'vue-sonner'
import 'vue-sonner/style.css'
import {
  CalendarDays,
  ChevronDown,
  Ellipsis,
  LayoutDashboard,
  ListOrdered,
  LogOut,
  ScrollText,
  ShieldCheck,
  Smartphone,
  Sparkles,
  UserRound,
  Wallet,
} from '@lucide/vue'

import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { useInstall } from '@/composables/useInstall'
import type { PageProps } from '@/types'

const page = usePage<PageProps>()

const NAV = [
  { href: '/', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/trades', label: 'Trade', icon: ListOrdered },
  { href: '/calendar', label: 'Kalender', icon: CalendarDays },
  { href: '/transactions', label: 'Dana', icon: Wallet },
  { href: '/rules', label: 'Aturan', icon: ScrollText },
  { href: '/analysis', label: 'Analisa', icon: Sparkles },
]

// Admin adalah peran pengelola, bukan trader: satu-satunya halamannya /admin.
const isAdmin = computed(() => !!page.props.auth.user?.is_admin)

const nav = computed(() =>
  isAdmin.value ? [{ href: '/admin', label: 'Admin', icon: ShieldCheck }] : NAV,
)

// Tab bar mobile: lima kolom dengan "Trade" tepat di tengah. Sisanya —
// Aturan dan Analisa — masuk ke menu "Lainnya" supaya tetap terjangkau.
const MOBILE_TABS = ['/', '/calendar', '/trades', '/transactions']

const mobileNav = computed(() =>
  isAdmin.value ? [] : MOBILE_TABS.map((href) => nav.value.find((item) => item.href === href)!),
)
const mobileMore = computed(() =>
  isAdmin.value ? [] : nav.value.filter((item) => !MOBILE_TABS.includes(item.href)),
)

// Layar chat AI tampil penuh: header dan tab bar disembunyikan, halaman
// mengisi seluruh tinggi layar seperti aplikasi chat pada umumnya.
// Tombol tutupnya ada di dalam halaman chat itu sendiri.
const fullscreen = computed(() => page.url.split('?')[0] === '/analysis/chat')

const { available: canInstall, install } = useInstall()

async function installApp() {
  const hint = await install()

  if (hint) toast.info(hint, { duration: 8000 })
}

const current = computed(() => page.props.currentAccount)
const accounts = computed(() => page.props.accounts ?? [])

function isActive(href: string): boolean {
  const path = page.url.split('?')[0]

  return href === '/' ? path === '/' : path.startsWith(href)
}

function switchAccount(id: number) {
  if (id !== current.value?.id) router.post(`/accounts/${id}/switch`)
}

// Flash dari server ditampilkan sebagai toast.
watch(
  () => page.props.flash,
  (flash) => {
    if (flash?.success) toast.success(flash.success)
    if (flash?.error) toast.error(flash.error)
    if (flash?.info) toast.info(flash.info)
  },
  { immediate: true, deep: true },
)
</script>

<template>
  <div class="flex min-h-screen flex-col" :class="fullscreen ? '' : 'pt-14'">
    <div class="bg-ornaments" aria-hidden="true">
      <div class="bg-grid" />
      <div class="ring-ornament" />
      <div class="blob blob-a" />
      <div class="blob blob-b" />
    </div>

    <header v-if="!fullscreen" class="glass fixed inset-x-0 top-0 z-40 h-14 border-b">
      <div class="mx-auto flex h-full max-w-7xl items-center gap-3 px-4">
        <Link href="/" class="flex shrink-0 items-center gap-2">
          <img src="/icons/icon-192.png" alt="Trade History" class="size-7 rounded-md" />
          <span class="hidden text-sm font-semibold tracking-tight sm:block">Trade History</span>
        </Link>

        <nav class="ml-4 hidden items-center gap-1 lg:flex">
          <Link
            v-for="item in nav"
            :key="item.href"
            :href="item.href"
            class="rounded-md px-2.5 py-1.5 text-sm transition-colors"
            :class="isActive(item.href) ? 'bg-accent text-accent-foreground' : 'text-muted-foreground hover:text-foreground'"
          >
            {{ item.label }}
          </Link>
        </nav>

        <div class="ml-auto flex items-center gap-2">
          <DropdownMenu v-if="current && !isAdmin">
            <DropdownMenuTrigger as-child>
              <Button variant="outline" size="sm" class="max-w-[11rem] justify-between gap-2">
                <span class="truncate">{{ current.name }}</span>
                <ChevronDown class="size-3.5 opacity-60" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" class="w-56">
              <DropdownMenuLabel>Akun trading</DropdownMenuLabel>
              <DropdownMenuItem
                v-for="account in accounts"
                :key="account.id"
                class="flex items-center justify-between gap-2"
                @select="switchAccount(account.id)"
              >
                <span class="truncate">{{ account.name }}</span>
                <span v-if="account.id === current.id" class="size-1.5 shrink-0 rounded-full bg-gold" />
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem @select="router.visit('/accounts')">Kelola akun…</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>

          <Link v-else-if="!isAdmin" href="/accounts">
            <Button size="sm">Buat akun</Button>
          </Link>

          <span v-else class="rounded-full bg-gold/15 px-2.5 py-1 text-[11px] text-gold">Admin</span>

          <DropdownMenu>
            <DropdownMenuTrigger as-child>
              <Button variant="ghost" size="icon-sm" title="Akun saya">
                <UserRound class="size-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" class="w-48">
              <DropdownMenuLabel class="truncate font-normal text-muted-foreground">
                {{ page.props.auth.user?.email }}
              </DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem @select="router.visit('/profile')">Profil</DropdownMenuItem>
              <DropdownMenuItem v-if="canInstall" @select="installApp">
                <Smartphone class="size-4" />
                Pasang aplikasi
              </DropdownMenuItem>
              <DropdownMenuItem @select="router.post('/logout')">
                <LogOut class="size-4" />
                Keluar
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </header>

    <!-- Ruang bawah dipesan sebesar tinggi tab bar mengambang (~95px) plus
         jarak napas dan safe area — nav-nya `fixed`, jadi tidak ikut mendorong
         isi halaman. Angka ini terikat pada tinggi nav di bawah: kalau ikonnya
         diperbesar lagi, naikkan juga nilai ini. -->
    <main
      class="mx-auto w-full flex-1"
      :class="
        fullscreen
          ? 'h-[100dvh] overflow-hidden'
          : [
              'max-w-7xl px-4 py-6 lg:pb-10',
              isAdmin ? 'pb-10' : 'pb-[calc(7.5rem+env(safe-area-inset-bottom))]',
            ]
      "
    >
      <slot />
    </main>

    <!-- Tab bar mobile: island mengambang, tab aktif ditandai kotak emas. -->
    <div v-if="!isAdmin && !fullscreen" class="fixed inset-x-0 bottom-0 z-40 px-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))] lg:hidden">
      <nav class="glass grid grid-cols-5 rounded-[1.75rem] p-1.5 shadow-lg shadow-black/30">
        <Link
          v-for="item in mobileNav"
          :key="item.href"
          :href="item.href"
          class="flex flex-col items-center gap-1 py-1.5 text-[10px] font-medium transition-colors"
          :class="isActive(item.href) ? 'text-gold' : 'text-muted-foreground'"
        >
          <span
            class="grid size-10 place-items-center rounded-2xl transition-colors"
            :class="isActive(item.href) ? 'bg-gold/15 ring-1 ring-gold/25' : ''"
          >
            <component :is="item.icon" class="size-5" />
          </span>
          {{ item.label }}
        </Link>

        <DropdownMenu>
          <DropdownMenuTrigger
            class="flex w-full flex-col items-center gap-1 py-1.5 text-[10px] font-medium transition-colors"
            :class="mobileMore.some((item) => isActive(item.href)) ? 'text-gold' : 'text-muted-foreground'"
          >
            <span
              class="grid size-10 place-items-center rounded-2xl transition-colors"
              :class="mobileMore.some((item) => isActive(item.href)) ? 'bg-gold/15 ring-1 ring-gold/25' : ''"
            >
              <Ellipsis class="size-5" />
            </span>
            Lainnya
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" side="top" :side-offset="8" class="w-44">
            <DropdownMenuItem
              v-for="item in mobileMore"
              :key="item.href"
              :class="isActive(item.href) ? 'text-gold' : ''"
              @select="router.visit(item.href)"
            >
              <component :is="item.icon" class="size-4" />
              {{ item.label }}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </nav>
    </div>

    <Toaster position="top-center" theme="dark" rich-colors close-button :duration="3500" />
  </div>
</template>
