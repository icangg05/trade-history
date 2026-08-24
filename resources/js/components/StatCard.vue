<script setup lang="ts">
defineProps<{
  label: string
  value: string
  hint?: string | null
  tone?: 'default' | 'good' | 'bad' | 'gold'
}>()

const tones = {
  default: 'text-foreground',
  good: 'text-success',
  bad: 'text-destructive',
  gold: 'text-gold',
}
</script>

<template>
  <div class="glass-card hover-lift p-4">
    <p class="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">{{ label }}</p>
    <p class="tnum mt-1.5 font-mono text-xl font-semibold" :class="tones[tone ?? 'default']">{{ value }}</p>
    <p v-if="hint" class="mt-0.5 text-xs text-muted-foreground">{{ hint }}</p>
  </div>
</template>
