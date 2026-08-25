<script setup lang="ts">
import { Head } from '@inertiajs/vue3'

import AnalysisChat from '@/components/AnalysisChat.vue'

defineProps<{ period: string; aiEnabled: boolean }>()
</script>

<template>
  <Head title="Tanya AI" />

  <AnalysisChat :period="period" :enabled="aiEnabled" />
</template>
