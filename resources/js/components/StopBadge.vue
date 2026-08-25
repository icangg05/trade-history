<script setup lang="ts">
import { computed } from 'vue'

import type { StopState } from '@/types'

/**
 * Penanda stop yang sudah digeser: BE (persis di harga entry) atau SL+ (sudah
 * lewat entry, profit terkunci). Dipakai di riwayat trade, dashboard, dan
 * kalender supaya kolom R yang kosong selalu punya alasan yang terlihat.
 */
const props = defineProps<{ state?: StopState }>()

const TAG = {
  breakeven: { label: 'BE', title: 'Stop loss di harga entry — risiko nol, R tidak dihitung' },
  locked: { label: 'SL+', title: 'Stop loss sudah lewat entry — profit terkunci, R tidak dihitung' },
}

const tag = computed(() => (props.state === 'breakeven' || props.state === 'locked' ? TAG[props.state] : null))
</script>

<template>
  <span v-if="tag" class="rounded-full bg-cyan/15 px-1.5 text-[9px] whitespace-nowrap text-cyan" :title="tag.title">
    {{ tag.label }}
  </span>
</template>
