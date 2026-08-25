# Graph Report - trade-history  (2026-08-26)

## Corpus Check
- 192 files · ~48,631 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1143 nodes · 2020 edges · 82 communities (69 shown, 13 thin omitted)
- Extraction: 97% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 50 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `87e9deb3`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- useFormat.ts
- AiImportDialog.vue
- composer.json
- Illuminate\Database\Migrations\Migration
- Analysis.vue
- dropdown-menu/index.ts
- Form.vue
- select/index.ts
- compilerOptions
- scripts
- AppLayout.vue
- utils.ts
- TradeRequest
- EquityChart.vue
- Controller
- PnlCalendar.vue
- Admin.vue
- TestCase
- AccountStats
- dependencies
- AnalysisChat.vue
- Trade
- components.json
- devDependencies
- bootstrap/app.php
- Tabs.vue
- Alur import trade dari screenshot
- Gemini
- dialog/index.ts
- types/index.ts
- DropdownMenuSubContent.vue
- Calendar.vue
- SelectContent.vue
- Index.vue
- User
- Transactions.vue
- package.json
- App Icon 512 (rounded squircle, rising-chart mark)
- Tabel trades
- UserFactory.php
- Illuminate\Http\Request
- @inertiajs/vue3
- Account
- shadcn-vue (reka-ui)
- Illuminate\Database\Eloquent\Model
- Input.vue
- App\Services\AccountStats
- compose service: app (FrankenPHP dev)
- Penyimpanan bukti transfer privat
- Tabel accounts
- PWA (manifest + service worker tulis tangan)
- logging.php
- Inertia\Response
- TradeController
- DropdownMenuContent.vue
- Rules.vue
- AdminController.php
- AdminTest
- GeminiKey
- draw_icon
- TradeImportTest
- TransactionController.php
- @types/node
- Progress.vue
- DropdownMenuSub.vue
- Separator.vue
- console.php
- DialogContent.vue
- @tailwindcss/vite
- SelectTrigger.vue
- @vitejs/plugin-vue
- AnalysisChatTest
- DropdownMenuCheckboxItem.vue

## God Nodes (most connected - your core abstractions)
1. `cn()` - 52 edges
2. `Trade` - 40 edges
3. `Account` - 34 edges
4. `User` - 33 edges
5. `AccountStats` - 26 edges
6. `GeminiKey` - 25 edges
7. `Gemini` - 21 edges
8. `JournalTest` - 20 edges
9. `TradeController` - 18 edges
10. `TradeGroupTest` - 16 edges

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

## Communities (82 total, 13 thin omitted)

### Community 0 - "useFormat.ts"
Cohesion: 0.10
Nodes (22): axis, bars, changePct, niceStep(), props, totals, compact(), CURRENCIES (+14 more)

### Community 1 - "AiImportDialog.vue"
Cohesion: 0.22
Nodes (12): busy, close(), csrf(), emit, error, file, onDrop(), onPaste() (+4 more)

### Community 2 - "composer.json"
Cohesion: 0.05
Nodes (42): pestphp/pest-plugin, php-http/discovery, autoload, autoload-dev, psr-4, psr-4, config, allow-plugins (+34 more)

### Community 3 - "Illuminate\Database\Migrations\Migration"
Cohesion: 0.07
Nodes (4): Illuminate\Database\Migrations\Migration, Illuminate\Database\Schema\Blueprint, Illuminate\Support\Facades\DB, Illuminate\Support\Facades\Schema

### Community 4 - "Analysis.vue"
Cohesion: 0.14
Nodes (9): html, props, tones, currency, form, PERIODS, props, Breakdown (+1 more)

### Community 5 - "dropdown-menu/index.ts"
Cohesion: 0.06
Nodes (25): emits, forwarded, props, props, delegatedProps, forwardedProps, props, delegatedProps (+17 more)

### Community 6 - "Form.vue"
Cohesion: 0.09
Nodes (19): code, emit, props, typed, Props, ButtonVariants, form, form (+11 more)

### Community 7 - "select/index.ts"
Cohesion: 0.07
Nodes (18): emits, forwarded, props, props, delegatedProps, forwardedProps, props, props (+10 more)

### Community 8 - "compilerOptions"
Cohesion: 0.07
Nodes (26): DOM, DOM.Iterable, ESNext, node, resources/js/**/*.d.ts, resources/js/**/*.ts, resources/js/**/*.vue, vite/client (+18 more)

### Community 9 - "scripts"
Cohesion: 0.08
Nodes (26): scripts, dev, post-autoload-dump, post-create-project-cmd, post-root-package-install, post-update-cmd, pre-package-uninstall, setup (+18 more)

### Community 10 - "AppLayout.vue"
Cohesion: 0.10
Nodes (20): AUTH_PAGES, deferred, installed, InstallPromptEvent, isIos(), isStandalone(), listenForInstall(), useInstall() (+12 more)

### Community 11 - "utils.ts"
Cohesion: 0.08
Nodes (21): props, props, props, props, props, props, props, delegatedProps (+13 more)

### Community 12 - "TradeRequest"
Cohesion: 0.32
Nodes (3): TradeRequest, Illuminate\Contracts\Validation\Validator, Illuminate\Foundation\Http\FormRequest

### Community 13 - "EquityChart.vue"
Cohesion: 0.12
Nodes (14): active, areaPath, box, flowPoints, gridLines, hover, PAD, path (+6 more)

### Community 14 - "Controller"
Cohesion: 0.16
Nodes (5): LoginController, RegisterController, Controller, DashboardController, RuleController

### Community 15 - "PnlCalendar.vue"
Cohesion: 0.20
Nodes (8): emit, iso(), maxAbs, props, today, WEEKDAYS, weeks, DayStat

### Community 16 - "Admin.vue"
Cohesion: 0.08
Nodes (20): emit, options, props, selected, SETUPS, csrf(), editing, gemini (+12 more)

### Community 17 - "TestCase"
Cohesion: 0.13
Nodes (8): Illuminate\Foundation\Testing\RefreshDatabase, Illuminate\Foundation\Testing\TestCase, Illuminate\Http\Client\ConnectionException, Illuminate\Http\Client\RequestException, Illuminate\Support\Facades\Http, GeminiKeyTest, RegisterTest, TestCase

### Community 18 - "AccountStats"
Cohesion: 0.15
Nodes (7): Transaction, AppServiceProvider, AccountStats, Carbon\CarbonInterface, Illuminate\Support\Collection, Illuminate\Support\Facades\Route, Illuminate\Support\ServiceProvider

### Community 19 - "dependencies"
Cohesion: 0.11
Nodes (19): class-variance-authority, clsx, @lucide/vue, marked, dependencies, class-variance-authority, clsx, @lucide/vue (+11 more)

### Community 20 - "AnalysisChat.vue"
Cohesion: 0.10
Nodes (21): busy, clear(), closing, confirming, csrf(), draft, error, finishTyping() (+13 more)

### Community 21 - "Trade"
Cohesion: 0.13
Nodes (4): Trade, CarbonImmutable, JournalTest, TradeGroupTest

### Community 22 - "components.json"
Cohesion: 0.12
Nodes (16): aliases, components, composables, lib, ui, utils, iconLibrary, $schema (+8 more)

### Community 23 - "devDependencies"
Cohesion: 0.12
Nodes (17): concurrently, fontaine, laravel-vite-plugin, devDependencies, concurrently, fontaine, laravel-vite-plugin, tailwindcss (+9 more)

### Community 24 - "bootstrap/app.php"
Cohesion: 0.15
Nodes (11): EnsureAdmin, EnsureTrader, HandleInertiaRequests, RequireAccount, SetCurrentAccount, Closure, Illuminate\Foundation\Application, Illuminate\Foundation\Configuration\Exceptions (+3 more)

### Community 25 - "Tabs.vue"
Cohesion: 0.12
Nodes (11): delegatedProps, emits, forwarded, props, delegatedProps, props, delegatedProps, props (+3 more)

### Community 26 - "Alur import trade dari screenshot"
Cohesion: 0.15
Nodes (15): Alur kerja graphify untuk repo ini, robots.txt mengizinkan seluruh crawler, Alur import trade dari screenshot, AiImportDialog, Urutan pengerjaan 7 fase, Gemini::extractTrade(), Gemini API (gemini-3.5-flash), App\Services\Gemini (+7 more)

### Community 28 - "dialog/index.ts"
Cohesion: 0.08
Nodes (17): emits, forwarded, props, props, delegatedProps, forwardedProps, props, props (+9 more)

### Community 29 - "types/index.ts"
Cohesion: 0.15
Nodes (12): props, TAG, confirming, profile, removal, AccountBrief, CurrentAccount, Direction (+4 more)

### Community 30 - "DropdownMenuSubContent.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 31 - "Calendar.vue"
Cohesion: 0.09
Nodes (23): delegatedProps, props, BadgeVariants, clock(), frameClass(), frameGap(), Groupable, currency (+15 more)

### Community 32 - "SelectContent.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 33 - "Index.vue"
Cohesion: 0.09
Nodes (21): dateTime(), longDate(), apply, blockRange(), currency, editGroup(), filters, groupForm (+13 more)

### Community 34 - "User"
Cohesion: 0.15
Nodes (8): User, DatabaseSeeder, DemoSeeder, Illuminate\Database\Eloquent\Attributes\Hidden, Illuminate\Database\Eloquent\Factories\HasFactory, Illuminate\Database\Seeder, Illuminate\Foundation\Auth\User, Illuminate\Notifications\Notifiable

### Community 35 - "Transactions.vue"
Cohesion: 0.14
Nodes (9): pages, props, currency, form, open, proofPreview, removing, Row (+1 more)

### Community 36 - "package.json"
Cohesion: 0.20
Nodes (9): @laravel/multiplex, optionalDependencies, @laravel/multiplex, private, $schema, scripts, build, dev (+1 more)

### Community 37 - "App Icon 512 (rounded squircle, rising-chart mark)"
Cohesion: 0.42
Nodes (10): Apple Touch Icon 180 (iOS home screen), App Icon 192 (PWA install/home-screen size), Favicon 32 (browser tab size), Small-Size Legibility Simplification, App Icon 512 (rounded squircle, rising-chart mark), Rising Trend Line Brand Mark, Rounded Squircle Container Treatment, Maskable Icon 192 (full-bleed, adaptive-mask safe) (+2 more)

### Community 38 - "Tabel trades"
Cohesion: 0.20
Nodes (10): Kolom ai_raw (jejak bacaan Gemini), Font self-host via bunny() laravel-vite-plugin, Mata uang akun USD / USC / IDR, Inertia v3 + Vue 3 (script setup, TS), Laravel 13 monolith, price() di useFormat.ts, Kolom RR menampilkan R hasil dan R rencana, Screenshot trade tidak disimpan (+2 more)

### Community 39 - "UserFactory.php"
Cohesion: 0.18
Nodes (6): UserFactory, Illuminate\Database\Eloquent\Factories\Factory, Illuminate\Support\Facades\Hash, Illuminate\Support\Str, Pdo\Mysql, static

### Community 40 - "Illuminate\Http\Request"
Cohesion: 0.21
Nodes (5): AccountController, AdminController, ProfileController, Illuminate\Http\RedirectResponse, Illuminate\Http\Request

### Community 42 - "Account"
Cohesion: 0.22
Nodes (4): Account, Illuminate\Database\Eloquent\Relations\HasMany, Illuminate\Http\UploadedFile, Illuminate\Support\Facades\Storage

### Community 43 - "shadcn-vue (reka-ui)"
Cohesion: 0.32
Nodes (8): Tema dark-only, Token warna nfp dark di-flatten ke :root, Utilities .glass / ornamen / hover-lift, PnlCalendar (grid CSS 7 kolom manual), Aturan warna semantik (gold / success / destructive / cyan), shadcn-vue (reka-ui), Tailwind CSS v4 (CSS-first), Waktu disimpan dalam Asia/Jakarta

### Community 44 - "Illuminate\Database\Eloquent\Model"
Cohesion: 0.17
Nodes (6): AccountRule, AiAnalysis, Illuminate\Database\Eloquent\Attributes\Fillable, Illuminate\Database\Eloquent\Model, Illuminate\Database\Eloquent\Relations\BelongsTo, Illuminate\Database\Eloquent\Relations\HasOne

### Community 45 - "Input.vue"
Cohesion: 0.50
Nodes (3): emits, modelValue, props

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

### Community 52 - "Inertia\Response"
Cohesion: 0.24
Nodes (7): CalendarController, Carbon\CarbonImmutable, Illuminate\Support\Facades\Auth, Illuminate\Validation\Rules\Password, Illuminate\Validation\ValidationException, Inertia\Inertia, Inertia\Response

### Community 54 - "DropdownMenuContent.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 55 - "Rules.vue"
Cohesion: 0.15
Nodes (11): breached, lossPct, profitPct, props, useCurrency(), currency, form, preview (+3 more)

### Community 56 - "AdminController.php"
Cohesion: 0.21
Nodes (7): TradeImportController, Illuminate\Http\JsonResponse, Illuminate\Support\Facades\Log, Illuminate\Support\Facades\Process, Illuminate\Validation\Rule, RuntimeException, Throwable

### Community 59 - "draw_icon"
Cohesion: 0.67
Nodes (3): Image, draw_icon(), main()

### Community 61 - "TransactionController.php"
Cohesion: 0.27
Nodes (3): TransactionController, Uploads, Symfony\Component\HttpFoundation\StreamedResponse

### Community 64 - "DropdownMenuSub.vue"
Cohesion: 0.50
Nodes (3): emits, forwarded, props

### Community 67 - "DialogContent.vue"
Cohesion: 0.25
Nodes (6): delegatedProps, emits, forwarded, props, delegatedProps, props

### Community 69 - "SelectTrigger.vue"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 81 - "DropdownMenuCheckboxItem.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

## Ambiguous Edges - Review These
- `robots.txt mengizinkan seluruh crawler` → `REGISTER_TOKEN penjaga pendaftaran mandiri`  [AMBIGUOUS]
  public/robots.txt · relation: conceptually_related_to

## Knowledge Gaps
- **396 isolated node(s):** `$schema`, `style`, `typescript`, `config`, `css` (+391 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `robots.txt mengizinkan seluruh crawler` and `REGISTER_TOKEN penjaga pendaftaran mandiri`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `cn()` connect `utils.ts` to `SelectContent.vue`, `Separator.vue`, `DialogContent.vue`, `dropdown-menu/index.ts`, `Form.vue`, `select/index.ts`, `SelectTrigger.vue`, `Input.vue`, `DropdownMenuCheckboxItem.vue`, `AnalysisChat.vue`, `DropdownMenuContent.vue`, `Tabs.vue`, `dialog/index.ts`, `Progress.vue`, `DropdownMenuSubContent.vue`, `Calendar.vue`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **Why does `Account` connect `Account` to `User`, `Illuminate\Http\Request`, `Illuminate\Database\Eloquent\Model`, `AnalysisChatTest`, `TestCase`, `AccountStats`, `Trade`, `TradeImportTest`?**
  _High betweenness centrality (0.022) - this node is a cross-community bridge._
- **Why does `User` connect `User` to `UserFactory.php`, `Illuminate\Http\Request`, `Account`, `Controller`, `AnalysisChatTest`, `TestCase`, `Inertia\Response`, `Trade`, `AdminController.php`, `AdminTest`, `TradeImportTest`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **What connects `$schema`, `style`, `typescript` to the rest of the system?**
  _396 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `useFormat.ts` be split into smaller, more focused modules?**
  _Cohesion score 0.0960591133004926 - nodes in this community are weakly interconnected._
- **Should `composer.json` be split into smaller, more focused modules?**
  _Cohesion score 0.046511627906976744 - nodes in this community are weakly interconnected._