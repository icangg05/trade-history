<script setup lang="ts">
import { computed } from 'vue'
import { marked } from 'marked'

const props = defineProps<{ source: string }>()

// Sumbernya hanya catatan milik pengguna sendiri dan keluaran Gemini —
// tidak ada input pihak ketiga yang masuk ke sini.
const html = computed(() => marked.parse(props.source ?? '', { async: false }) as string)
</script>

<template>
  <div class="rte-content" v-html="html" />
</template>
