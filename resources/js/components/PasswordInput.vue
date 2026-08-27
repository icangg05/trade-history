<script setup lang="ts">
import { ref } from 'vue'
import { Eye, EyeOff } from '@lucide/vue'

import { Input } from '@/components/ui/input'

/** Kolom kata sandi dengan tombol lihat/sembunyikan di ujung kanannya. */
defineOptions({ inheritAttrs: false })

const model = defineModel<string>({ required: true })
const shown = ref(false)
</script>

<template>
  <div class="relative">
    <Input v-bind="$attrs" v-model="model" :type="shown ? 'text' : 'password'" class="pr-10" />

    <!-- Di luar urutan tab: keyboard cukup lanjut ke kolom berikutnya. -->
    <button
      type="button"
      tabindex="-1"
      class="absolute inset-y-0 right-0 grid w-10 place-items-center rounded-r-md text-muted-foreground transition-colors hover:text-foreground"
      :aria-label="shown ? 'Sembunyikan kata sandi' : 'Lihat kata sandi'"
      :title="shown ? 'Sembunyikan kata sandi' : 'Lihat kata sandi'"
      @click="shown = !shown"
    >
      <component :is="shown ? EyeOff : Eye" class="size-4" />
    </button>
  </div>
</template>
