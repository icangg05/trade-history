import { defineConfig } from 'vite'
import ts from 'typescript'
import { registerTS } from '@vue/compiler-sfc'
import fs from 'node:fs'
import { resolve } from 'node:path'
import laravel from 'laravel-vite-plugin'
import { bunny } from 'laravel-vite-plugin/fonts'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

// Compiler SFC butuh modul TypeScript untuk menelusuri tipe yang di-import
// (mis. props reka-ui di komponen shadcn); di Vite 8 ia tidak menemukannya sendiri.
registerTS(() => ts)

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.ts'],
            refresh: true,
            fonts: [
                bunny('IBM Plex Sans', { weights: [400, 500, 600, 700] }),
                bunny('IBM Plex Mono', { weights: [400, 500, 600] }),
            ],
        }),
        vue({
            template: { transformAssetUrls: { base: null, includeAbsolute: false } },
            // Vite 8 menjalankan compiler SFC di luar Node, jadi akses berkas
            // untuk resolusi tipe lintas file harus disuntik manual.
            script: {
                fs: {
                    fileExists: (file) => fs.existsSync(file),
                    readFile: (file) => fs.readFileSync(file, 'utf-8'),
                    realpath: (file) => fs.realpathSync(file),
                },
            },
        }),
        tailwindcss(),
    ],
    resolve: {
        alias: { '@': resolve(__dirname, 'resources/js') },
    },
    server: {
        host: '0.0.0.0',
        port: 5173,
        hmr: { host: 'localhost' },
        watch: { ignored: ['**/storage/framework/views/**'], usePolling: true },
    },
})
