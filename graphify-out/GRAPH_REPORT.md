# Graph Report - trade-history  (2026-08-30)

## Corpus Check
- 214 files · ~64,929 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1341 nodes · 2502 edges · 97 communities (82 shown, 15 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 50 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d267ac38`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Illuminate\Database\Eloquent\Model
- Gemini
- composer.json
- Illuminate\Database\Migrations\Migration
- TradeController
- dropdown-menu/index.ts
- cn
- select/index.ts
- compilerOptions
- scripts
- AppLayout.vue
- utils.ts
- require-dev
- useFormat.ts
- setup
- EquityChart.vue
- Admin.vue
- TestCase
- AccountStats
- dependencies
- AnalysisChat.vue
- GeminiKey
- components.json
- devDependencies
- bootstrap/app.php
- Tabs.vue
- Alur import trade dari screenshot
- TradeImportTest
- dialog/index.ts
- Rules.vue
- AnalysisChatTest
- Calendar.vue
- button/index.ts
- Index.vue
- User
- Transactions.vue
- package.json
- App Icon 512 (rounded squircle, rising-chart mark)
- Tabel trades
- AiImportDialog.vue
- Carbon\CarbonImmutable
- types/index.ts
- AnalysisTest
- shadcn-vue (reka-ui)
- Trade
- Form.vue
- App\Services\AccountStats
- compose service: app (FrankenPHP dev)
- Penyimpanan bukti transfer privat
- Tabel accounts
- PWA (manifest + service worker tulis tangan)
- logging.php
- config
- Account
- User.php
- Input.vue
- extra
- Illuminate\Http\RedirectResponse
- require
- draw_icon
- LoginThrottleTest
- Hashid
- @types/node
- Progress.vue
- psr-4
- Separator.vue
- BackupDatabase
- DialogContent.vue
- @tailwindcss/vite
- Inertia\Response
- post-create-project-cmd
- Illuminate\Http\Request
- DropdownMenuCheckboxItem.vue
- web.php
- SelectContent.vue
- RuleLimitTest
- TradeImportController.php
- Controller
- Illuminate\Support\Str
- TradeRequest
- DropdownMenuRadioItem.vue
- DropdownMenuLabel.vue
- DropdownMenuSubTrigger.vue
- @inertiajs/vue3
- @vitejs/plugin-vue
- ReportController
- Report.vue

## God Nodes (most connected - your core abstractions)
1. `User` - 80 edges
2. `cn()` - 52 edges
3. `Account` - 49 edges
4. `Trade` - 41 edges
5. `TestCase` - 34 edges
6. `AccountStats` - 31 edges
7. `ReportTest` - 29 edges
8. `GeminiKey` - 28 edges
9. `JournalTest` - 25 edges
10. `Gemini` - 21 edges

## Surprising Connections (you probably didn't know these)
- `Penyimpanan bukti transfer privat` --semantically_similar_to--> `Screenshot trade tidak disimpan`  [INFERRED] [semantically similar]
  README.md → RANCANGAN.md
- `robots.txt mengizinkan seluruh crawler` --conceptually_related_to--> `REGISTER_TOKEN penjaga pendaftaran mandiri`  [AMBIGUOUS]
  public/robots.txt → README.md
- `compose service: app (FrankenPHP dev)` --implements--> `FrankenPHP + Laravel Octane (worker mode)`  [EXTRACTED]
  compose.yml → RANCANGAN.md
- `compose service: vite (node:24-slim, one-shot)` --implements--> `Vite 8 (rolldown)`  [EXTRACTED]
  compose.yml → RANCANGAN.md
- `Tabel gemini_settings (kunci API terenkripsi)` --shares_data_with--> `App\Services\Gemini`  [EXTRACTED]
  README.md → RANCANGAN.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Pipeline import trade dari screenshot** — rancangan_aiimportdialog, rancangan_extracttrade, rancangan_layered_verification, rancangan_traderequest, rancangan_tradeform, rancangan_ai_raw, rancangan_screenshot_not_stored [EXTRACTED 1.00]
- **Stack dev docker compose** — compose_app_service, compose_mysql_service, compose_vite_service, compose_host_user_mapping, compose_no_env_file, compose_healthcheck_up, compose_storage_bind_mount [EXTRACTED 1.00]
- **Design system dark-only** — rancangan_dark_only_theme, rancangan_design_tokens, rancangan_glass_utilities, rancangan_semantic_color_rules, rancangan_typography_mono [EXTRACTED 1.00]
- **Maskable-Purpose Icon Variants** — public_icons_maskable_512_maskable_icon, public_icons_maskable_192_maskable_icon, public_icons_maskable_512_safe_zone [INFERRED 0.85]
- **PWA / Web App Manifest Icon Set** — public_icons_icon_512_app_icon, public_icons_icon_192_app_icon, public_icons_icon_32_favicon, public_icons_apple_touch_icon_icon, public_icons_maskable_512_maskable_icon, public_icons_maskable_192_maskable_icon [INFERRED 0.95]

## Communities (97 total, 15 thin omitted)

### Community 0 - "Illuminate\Database\Eloquent\Model"
Cohesion: 0.18
Nodes (6): AccountRule, AiAnalysis, Illuminate\Database\Eloquent\Attributes\Fillable, Illuminate\Database\Eloquent\Model, Illuminate\Database\Eloquent\Relations\BelongsTo, Illuminate\Database\Eloquent\Relations\HasOne

### Community 1 - "Gemini"
Cohesion: 0.35
Nodes (3): Gemini, Illuminate\Http\Client\ConnectionException, Illuminate\Http\Client\RequestException

### Community 2 - "composer.json"
Cohesion: 0.14
Nodes (13): autoload-dev, psr-4, description, keywords, license, minimum-stability, name, prefer-stable (+5 more)

### Community 3 - "Illuminate\Database\Migrations\Migration"
Cohesion: 0.06
Nodes (4): Illuminate\Database\Migrations\Migration, Illuminate\Database\Schema\Blueprint, Illuminate\Support\Facades\DB, Illuminate\Support\Facades\Schema

### Community 5 - "dropdown-menu/index.ts"
Cohesion: 0.06
Nodes (25): emits, forwarded, props, delegatedProps, emits, forwarded, props, props (+17 more)

### Community 6 - "cn"
Cohesion: 0.12
Nodes (11): delegatedProps, props, props, props, props, props, props, props (+3 more)

### Community 7 - "select/index.ts"
Cohesion: 0.06
Nodes (21): emits, forwarded, props, props, delegatedProps, forwardedProps, props, props (+13 more)

### Community 8 - "compilerOptions"
Cohesion: 0.07
Nodes (26): DOM, DOM.Iterable, ESNext, node, resources/js/**/*.d.ts, resources/js/**/*.ts, resources/js/**/*.vue, vite/client (+18 more)

### Community 9 - "scripts"
Cohesion: 0.14
Nodes (14): scripts, dev, post-autoload-dump, post-update-cmd, pre-package-uninstall, test, Composer\\Config::disableProcessTimeout, Illuminate\\Foundation\\ComposerScripts::postAutoloadDump (+6 more)

### Community 10 - "AppLayout.vue"
Cohesion: 0.10
Nodes (20): BARE_PAGES, deferred, installed, InstallPromptEvent, isIos(), isStandalone(), listenForInstall(), useInstall() (+12 more)

### Community 11 - "utils.ts"
Cohesion: 0.13
Nodes (11): props, props, props, props, props, delegatedProps, props, props (+3 more)

### Community 12 - "require-dev"
Cohesion: 0.25
Nodes (8): require-dev, fakerphp/faker, laravel/pail, laravel/pao, laravel/pint, mockery/mockery, nunomaduro/collision, phpunit/phpunit

### Community 13 - "useFormat.ts"
Cohesion: 0.08
Nodes (33): axis, bars, changePct, niceStep(), props, totals, breached, lossPct (+25 more)

### Community 14 - "setup"
Cohesion: 0.25
Nodes (8): post-root-package-install, setup, composer install, npm install --ignore-scripts, npm run build, @php artisan key:generate, @php artisan migrate --force, @php -r \"file_exists('.env') || copy('.env.example', '.env');\

### Community 15 - "EquityChart.vue"
Cohesion: 0.12
Nodes (15): active, areaPath, box, flowPoints, gridLines, hover, PAD, path (+7 more)

### Community 16 - "Admin.vue"
Cohesion: 0.09
Nodes (17): backingUp, Backup, csrf(), editing, gemini, GeminiKey, now, open (+9 more)

### Community 17 - "TestCase"
Cohesion: 0.10
Nodes (9): Illuminate\Foundation\Testing\RefreshDatabase, Illuminate\Foundation\Testing\TestCase, Illuminate\Support\Facades\Http, ErrorPageTest, FlashTest, GeminiKeyTest, RegisterTest, TradeDayTest (+1 more)

### Community 18 - "AccountStats"
Cohesion: 0.21
Nodes (3): AccountStats, Carbon\CarbonInterface, Illuminate\Support\Collection

### Community 19 - "dependencies"
Cohesion: 0.11
Nodes (19): class-variance-authority, clsx, @lucide/vue, marked, dependencies, class-variance-authority, clsx, @lucide/vue (+11 more)

### Community 20 - "AnalysisChat.vue"
Cohesion: 0.12
Nodes (20): busy, clear(), close(), closing, confirming, csrf(), draft, error (+12 more)

### Community 22 - "components.json"
Cohesion: 0.12
Nodes (16): aliases, components, composables, lib, ui, utils, iconLibrary, $schema (+8 more)

### Community 23 - "devDependencies"
Cohesion: 0.12
Nodes (17): concurrently, fontaine, laravel-vite-plugin, devDependencies, concurrently, fontaine, laravel-vite-plugin, tailwindcss (+9 more)

### Community 24 - "bootstrap/app.php"
Cohesion: 0.17
Nodes (11): EnsureAdmin, EnsureTrader, RequireAccount, SetCurrentAccount, Closure, Illuminate\Foundation\Application, Illuminate\Foundation\Configuration\Exceptions, Illuminate\Foundation\Configuration\Middleware (+3 more)

### Community 25 - "Tabs.vue"
Cohesion: 0.12
Nodes (11): delegatedProps, emits, forwarded, props, delegatedProps, props, delegatedProps, props (+3 more)

### Community 26 - "Alur import trade dari screenshot"
Cohesion: 0.15
Nodes (15): Alur kerja graphify untuk repo ini, robots.txt mengizinkan seluruh crawler, Alur import trade dari screenshot, AiImportDialog, Urutan pengerjaan 7 fase, Gemini::extractTrade(), Gemini API (gemini-3.5-flash), App\Services\Gemini (+7 more)

### Community 28 - "dialog/index.ts"
Cohesion: 0.08
Nodes (17): emits, forwarded, props, props, delegatedProps, forwardedProps, props, props (+9 more)

### Community 29 - "Rules.vue"
Cohesion: 0.12
Nodes (15): html, props, useCurrency(), AmountKey, currency, dailyLoss, dailyTarget, estimate() (+7 more)

### Community 31 - "Calendar.vue"
Cohesion: 0.09
Nodes (20): emit, iso(), maxAbs, props, today, WEEKDAYS, weeks, BadgeVariants (+12 more)

### Community 32 - "button/index.ts"
Cohesion: 0.06
Nodes (26): FEATURES, code, emit, props, typed, model, shown, Props (+18 more)

### Community 33 - "Index.vue"
Cohesion: 0.07
Nodes (29): longDate(), frameClass(), frameGap(), frameTop(), Groupable, apply, blockRange(), currency (+21 more)

### Community 34 - "User"
Cohesion: 0.19
Nodes (4): User, AnnualReport, Illuminate\Foundation\Auth\User, ReportTest

### Community 35 - "Transactions.vue"
Cohesion: 0.09
Nodes (20): pages, props, monthLabel(), rateCurrency(), toIdr(), currency, form, inIdr() (+12 more)

### Community 36 - "package.json"
Cohesion: 0.20
Nodes (9): @laravel/multiplex, optionalDependencies, @laravel/multiplex, private, $schema, scripts, build, dev (+1 more)

### Community 37 - "App Icon 512 (rounded squircle, rising-chart mark)"
Cohesion: 0.42
Nodes (10): Apple Touch Icon 180 (iOS home screen), App Icon 192 (PWA install/home-screen size), Favicon 32 (browser tab size), Small-Size Legibility Simplification, App Icon 512 (rounded squircle, rising-chart mark), Rising Trend Line Brand Mark, Rounded Squircle Container Treatment, Maskable Icon 192 (full-bleed, adaptive-mask safe) (+2 more)

### Community 38 - "Tabel trades"
Cohesion: 0.20
Nodes (10): Kolom ai_raw (jejak bacaan Gemini), Font self-host via bunny() laravel-vite-plugin, Mata uang akun USD / USC / IDR, Inertia v3 + Vue 3 (script setup, TS), Laravel 13 monolith, price() di useFormat.ts, Kolom RR menampilkan R hasil dan R rencana, Screenshot trade tidak disimpan (+2 more)

### Community 39 - "AiImportDialog.vue"
Cohesion: 0.22
Nodes (12): busy, close(), csrf(), emit, error, file, onDrop(), onPaste() (+4 more)

### Community 40 - "Carbon\CarbonImmutable"
Cohesion: 0.16
Nodes (8): CalendarController, CarbonImmutable, TransactionController, Transaction, Uploads, Carbon\CarbonImmutable, Illuminate\Support\Facades\URL, Symfony\Component\HttpFoundation\StreamedResponse

### Community 41 - "types/index.ts"
Cohesion: 0.12
Nodes (14): props, TAG, message, MESSAGES, props, signedIn, AccountBrief, CurrentAccount (+6 more)

### Community 43 - "shadcn-vue (reka-ui)"
Cohesion: 0.32
Nodes (8): Tema dark-only, Token warna nfp dark di-flatten ke :root, Utilities .glass / ornamen / hover-lift, PnlCalendar (grid CSS 7 kolom manual), Aturan warna semantik (gold / success / destructive / cyan), shadcn-vue (reka-ui), Tailwind CSS v4 (CSS-first), Waktu disimpan dalam Asia/Jakarta

### Community 44 - "Trade"
Cohesion: 0.11
Nodes (3): Trade, JournalTest, TradeGroupTest

### Community 45 - "Form.vue"
Cohesion: 0.10
Nodes (16): emit, options, props, selected, SETUPS, aiFields, aiPreview, currency (+8 more)

### Community 46 - "App\Services\AccountStats"
Cohesion: 0.38
Nodes (7): App\Services\AccountStats, Tabel ai_analyses (cache hasil Gemini), Alur analisa AI berbasis statistik, Gemini::analyze(), EquityChart.vue (SVG murni), MonthlyPnlChart.vue (SVG murni), Tanpa tabel ledger/snapshot saldo

### Community 47 - "compose service: app (FrankenPHP dev)"
Cohesion: 0.33
Nodes (6): compose service: app (FrankenPHP dev), Healthcheck app memakai route /up, compose service: mysql 8.4, Tanpa env_file pada service app, FrankenPHP + Laravel Octane (worker mode), MySQL 8.4

### Community 48 - "Penyimpanan bukti transfer privat"
Cohesion: 0.33
Nodes (6): Kontainer berjalan sebagai UID/GID host, Bind mount ./storage/app, compose service: vite (node:24-slim, one-shot), Tabel transactions (deposit/withdrawal), Penyimpanan bukti transfer privat, App\Services\Uploads (bukti transfer di disk privat)

### Community 49 - "Tabel accounts"
Cohesion: 0.40
Nodes (6): Tabel account_rules (kolom eksplisit, 1:1 akun), Account switcher di header, Tabel accounts, Aturan trading tidak memblokir input, RuleStatusBanner, Middleware SetCurrentAccount

### Community 50 - "PWA (manifest + service worker tulis tangan)"
Cohesion: 0.33
Nodes (6): Menu "Pasang aplikasi" + manifest.id, PWA (manifest + service worker tulis tangan), public/sw.js (cache aset build saja), TypeScript dipatok ^5.9, Vite 8 (rolldown), scripts/make-icons.py (generator ikon PWA)

### Community 51 - "logging.php"
Cohesion: 0.40
Nodes (4): Monolog\Handler\NullHandler, Monolog\Handler\StreamHandler, Monolog\Handler\SyslogUdpHandler, Monolog\Processor\PsrLogMessageProcessor

### Community 52 - "config"
Cohesion: 0.29
Nodes (7): pestphp/pest-plugin, php-http/discovery, config, allow-plugins, optimize-autoloader, preferred-install, sort-packages

### Community 53 - "Account"
Cohesion: 0.14
Nodes (7): Account, DatabaseSeeder, DemoSeeder, Illuminate\Database\Eloquent\Relations\HasMany, Illuminate\Database\Seeder, Illuminate\Http\UploadedFile, Illuminate\Support\Facades\Storage

### Community 54 - "User.php"
Cohesion: 0.14
Nodes (8): UserFactory, Illuminate\Database\Eloquent\Attributes\Hidden, Illuminate\Database\Eloquent\Factories\Factory, Illuminate\Database\Eloquent\Factories\HasFactory, Illuminate\Notifications\Notifiable, Illuminate\Support\Facades\Hash, static, ProfileTest

### Community 55 - "Input.vue"
Cohesion: 0.50
Nodes (3): emits, modelValue, props

### Community 56 - "extra"
Cohesion: 0.67
Nodes (3): extra, laravel, dont-discover

### Community 57 - "Illuminate\Http\RedirectResponse"
Cohesion: 0.22
Nodes (4): AdminController, Illuminate\Http\JsonResponse, Illuminate\Http\RedirectResponse, Symfony\Component\HttpFoundation\BinaryFileResponse

### Community 58 - "require"
Cohesion: 0.25
Nodes (8): require, dompdf/dompdf, hashids/hashids, inertiajs/inertia-laravel, laravel/framework, laravel/octane, laravel/tinker, php

### Community 59 - "draw_icon"
Cohesion: 0.67
Nodes (3): Image, draw_icon(), main()

### Community 61 - "Hashid"
Cohesion: 0.24
Nodes (5): getRouteKey(), AppServiceProvider, Hashid, Hashids\Hashids, Illuminate\Support\ServiceProvider

### Community 64 - "psr-4"
Cohesion: 0.40
Nodes (5): autoload, psr-4, App\\, Database\\Factories\\, Database\\Seeders\\

### Community 66 - "BackupDatabase"
Cohesion: 0.09
Nodes (11): BackupDatabase, CarbonImmutable, Illuminate\Console\Command, Illuminate\Foundation\Inspiring, Illuminate\Support\Carbon, Illuminate\Support\Facades\Artisan, Illuminate\Support\Facades\File, Illuminate\Support\Facades\Process (+3 more)

### Community 67 - "DialogContent.vue"
Cohesion: 0.25
Nodes (6): delegatedProps, emits, forwarded, props, delegatedProps, props

### Community 69 - "Inertia\Response"
Cohesion: 0.23
Nodes (3): DashboardController, RuleController, Inertia\Response

### Community 70 - "post-create-project-cmd"
Cohesion: 0.50
Nodes (4): post-create-project-cmd, @php artisan key:generate --ansi, @php artisan migrate --graceful --ansi, @php -r \"file_exists('database/database.sqlite') || touch('database/database.sqlite');\

### Community 80 - "Illuminate\Http\Request"
Cohesion: 0.20
Nodes (5): AccountController, AnalysisController, HandleInertiaRequests, Illuminate\Http\Request, Inertia\Middleware

### Community 81 - "DropdownMenuCheckboxItem.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 82 - "web.php"
Cohesion: 0.24
Nodes (3): LoginController, RegisterController, Illuminate\Support\Facades\Route

### Community 83 - "SelectContent.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 85 - "TradeImportController.php"
Cohesion: 0.32
Nodes (4): TradeImportController, Illuminate\Support\Facades\Log, RuntimeException, Throwable

### Community 86 - "Controller"
Cohesion: 0.15
Nodes (11): Controller, ProfileController, Dompdf\Dompdf, Illuminate\Auth\Events\Lockout, Illuminate\Database\Eloquent\Collection, Illuminate\Support\Facades\Auth, Illuminate\Support\Facades\RateLimiter, Illuminate\Validation\Rule (+3 more)

### Community 88 - "TradeRequest"
Cohesion: 0.32
Nodes (3): TradeRequest, Illuminate\Contracts\Validation\Validator, Illuminate\Foundation\Http\FormRequest

### Community 89 - "DropdownMenuRadioItem.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 90 - "DropdownMenuLabel.vue"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 91 - "DropdownMenuSubTrigger.vue"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 96 - "Report.vue"
Cohesion: 0.14
Nodes (10): emits, modelValue, props, errors, foreign, form, page, parsedRate (+2 more)

## Ambiguous Edges - Review These
- `robots.txt mengizinkan seluruh crawler` → `REGISTER_TOKEN penjaga pendaftaran mandiri`  [AMBIGUOUS]
  public/robots.txt · relation: conceptually_related_to

## Knowledge Gaps
- **431 isolated node(s):** `$schema`, `style`, `typescript`, `config`, `css` (+426 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `robots.txt mengizinkan seluruh crawler` and `REGISTER_TOKEN penjaga pendaftaran mandiri`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `User` connect `User` to `BackupDatabase`, `Inertia\Response`, `AnalysisTest`, `Trade`, `TestCase`, `web.php`, `RuleLimitTest`, `Account`, `User.php`, `Controller`, `GeminiKey`, `Illuminate\Http\RedirectResponse`, `TradeImportTest`, `LoginThrottleTest`, `AnalysisChatTest`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Why does `cn()` connect `cn` to `button/index.ts`, `Separator.vue`, `Report.vue`, `DialogContent.vue`, `dropdown-menu/index.ts`, `select/index.ts`, `utils.ts`, `DropdownMenuCheckboxItem.vue`, `SelectContent.vue`, `Input.vue`, `DropdownMenuRadioItem.vue`, `DropdownMenuLabel.vue`, `DropdownMenuSubTrigger.vue`, `dialog/index.ts`, `Tabs.vue`, `Progress.vue`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Why does `Account` connect `Account` to `Illuminate\Database\Eloquent\Model`, `BackupDatabase`, `User`, `Carbon\CarbonImmutable`, `AnalysisTest`, `Trade`, `Illuminate\Http\Request`, `TestCase`, `AccountStats`, `RuleLimitTest`, `Controller`, `AnalysisChatTest`, `Illuminate\Http\RedirectResponse`, `TradeImportTest`, `Hashid`, `ReportController`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **What connects `$schema`, `style`, `typescript` to the rest of the system?**
  _431 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `composer.json` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `Illuminate\Database\Migrations\Migration` be split into smaller, more focused modules?**
  _Cohesion score 0.05858585858585859 - nodes in this community are weakly interconnected._