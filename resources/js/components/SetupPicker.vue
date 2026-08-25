<script setup lang="ts">
import { computed } from 'vue'

/**
 * Satu trade sering memakai beberapa strategi sekaligus, jadi `setup` disimpan
 * sebagai daftar dipisah koma. Nilai yang tidak ada di daftar bawaan (mis. hasil
 * baca AI atau trade lama) tetap muncul sebagai pilihan supaya tidak hilang saat
 * diedit.
 */
const SETUPS = [
  'Supply Demand',
  'Support Resisten',
  'Fibonacci',
  'Order Block',
  'FVG',
  'Parallel Channel',
  'Break of Structure',
  'CHoCH',
  'Liquidity Sweep',
  'Trendline',
  'Moving Average',
  'Breakout',
  'Pullback',
  'Pola Candlestick',
  'Double Top',
  'Double Bottom',
  'Head & Shoulders',
  'Inv. Head & Shoulders',
  'Triple Top',
  'Triple Bottom',
  'Ascending Triangle',
  'Descending Triangle',
  'Symmetrical Triangle',
  'Rising Wedge',
  'Falling Wedge',
  'Flag',
  'Pennant',
  'Cup & Handle',
  'Rectangle / Range',
]

const props = defineProps<{ modelValue: string | null; disabled?: boolean; dense?: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [string] }>()

const selected = computed<string[]>({
  get: () => String(props.modelValue ?? '').split(',').map((item) => item.trim()).filter(Boolean),
  set: (list) => emit('update:modelValue', list.join(', ')),
})

const options = computed(() => [...new Set([...SETUPS, ...selected.value])])
</script>

<template>
  <div class="flex flex-wrap gap-2" :class="disabled ? 'pointer-events-none opacity-50' : ''">
    <label
      v-for="option in options"
      :key="option"
      class="flex cursor-pointer items-center gap-2 rounded-md border transition-colors"
      :class="[
        dense ? 'px-2 py-1 text-[11px]' : 'px-2.5 py-1.5 text-sm',
        selected.includes(option) ? 'border-gold/60 bg-gold/10 text-gold' : 'text-muted-foreground hover:text-foreground',
      ]"
    >
      <input v-model="selected" type="checkbox" :value="option" :disabled="disabled" class="size-3.5 accent-gold" />
      {{ option }}
    </label>
  </div>
</template>
