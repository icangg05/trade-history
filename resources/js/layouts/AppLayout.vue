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
  <div class="flex min-h-screen flex-col pt-14">
    <div class="bg-ornaments" aria-hidden="true">
      <div class="bg-grid" />
      <div class="ring-ornament" />
      <div class="blob blob-a" />
      <div class="blob blob-b" />
    </div>

    <header class="glass fixed inset-x-0 top-0 z-40 h-14 border-b">
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

    <main class="mx-auto w-full max-w-7xl flex-1 px-4 py-6 lg:pb-10" :class="isAdmin ? 'pb-10' : 'pb-24'">
      <slot />
    </main>

    <nav v-if="!isAdmin" class="glass pb-safe fixed inset-x-0 bottom-0 z-40 grid grid-cols-5 border-t lg:hidden">
      <Link
        v-for="item in mobileNav"
        :key="item.href"
        :href="item.href"
        class="flex flex-col items-center gap-0.5 py-1.5 text-[10px] transition-colors"
        :class="isActive(item.href) ? 'text-gold' : 'text-muted-foreground'"
      >
        <span
          class="grid place-items-center rounded-full px-3 py-1 transition-colors"
          :class="
            item.href === '/trades'
              ? isActive(item.href)
                ? 'bg-gold text-gold-foreground'
                : 'bg-gold/15 text-gold'
              : ''
          "
        >
          <component :is="item.icon" class="size-4" />
        </span>
        {{ item.label }}
      </Link>

      <DropdownMenu>
        <DropdownMenuTrigger
          class="flex w-full flex-col items-center gap-0.5 py-1.5 text-[10px] transition-colors"
          :class="mobileMore.some((item) => isActive(item.href)) ? 'text-gold' : 'text-muted-foreground'"
        >
          <span class="grid place-items-center px-3 py-1"><Ellipsis class="size-4" /></span>
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

    <Toaster position="top-center" theme="dark" rich-colors close-button :duration="3500" />
  </div>
</template>
