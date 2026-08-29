# Graph Report - trade-history  (2026-08-29)

## Corpus Check
- 210 files · ~62,588 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1308 nodes · 2412 edges · 101 communities (86 shown, 15 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 48 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `dc5aa4cf`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- GeminiKey
- Gemini
- composer.json
- Illuminate\Database\Migrations\Migration
- TradeController
- dropdown-menu/index.ts
- Accounts.vue
- select/index.ts
- compilerOptions
- scripts
- AppLayout.vue
- utils.ts
- require-dev
- EquityChart.vue
- setup
- PnlCalendar.vue
- Admin.vue
- TestCase
- AccountStats
- dependencies
- AnalysisChat.vue
- Illuminate\Database\Eloquent\Model
- components.json
- devDependencies
- bootstrap/app.php
- Tabs.vue
- Alur import trade dari screenshot
- Dashboard.vue
- dialog/index.ts
- Rules.vue
- button/index.ts
- Calendar.vue
- input/index.ts
- Index.vue
- User
- Transactions.vue
- package.json
- App Icon 512 (rounded squircle, rising-chart mark)
- Tabel trades
- AiImportDialog.vue
- SetupPicker.vue
- types/index.ts
- AdminTest
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
- DropdownMenuContent.vue
- Input.vue
- AnalysisChatTest
- Illuminate\Http\RedirectResponse
- require
- draw_icon
- Error.vue
- LoginController
- @types/node
- Progress.vue
- psr-4
- Separator.vue
- BackupDatabase
- DialogContent.vue
- @tailwindcss/vite
- useFormat.ts
- post-create-project-cmd
- Illuminate\Http\Request
- DropdownMenuCheckboxItem.vue
- DropdownMenuSubContent.vue
- SelectContent.vue
- TradeImportTest
- console.php
- Controller
- Inertia\Response
- TradeRequest
- User.php
- extra
- LoginThrottleTest
- AiAnalysis
- @vitejs/plugin-vue
- ReportController.php
- Analysis.vue
- Report.vue
- ConfirmDestroy.vue
- DemoSeeder.php
- @inertiajs/vue3

## God Nodes (most connected - your core abstractions)
1. `User` - 71 edges
2. `cn()` - 52 edges
3. `Account` - 49 edges
4. `Trade` - 40 edges
5. `AccountStats` - 32 edges
6. `TestCase` - 32 edges
7. `GeminiKey` - 28 edges
8. `JournalTest` - 23 edges
9. `Gemini` - 21 edges
10. `ReportTest` - 21 edges

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

## Communities (101 total, 15 thin omitted)

### Community 1 - "Gemini"
Cohesion: 0.17
Nodes (7): TradeImportController, Gemini, Illuminate\Http\Client\ConnectionException, Illuminate\Http\Client\RequestException, Illuminate\Support\Facades\Log, RuntimeException, Throwable

### Community 2 - "composer.json"
Cohesion: 0.14
Nodes (13): autoload-dev, psr-4, description, keywords, license, minimum-stability, name, prefer-stable (+5 more)

### Community 3 - "Illuminate\Database\Migrations\Migration"
Cohesion: 0.06
Nodes (4): Illuminate\Database\Migrations\Migration, Illuminate\Database\Schema\Blueprint, Illuminate\Support\Facades\DB, Illuminate\Support\Facades\Schema

### Community 5 - "dropdown-menu/index.ts"
Cohesion: 0.05
Nodes (28): emits, forwarded, props, props, delegatedProps, forwardedProps, props, delegatedProps (+20 more)

### Community 6 - "Accounts.vue"
Cohesion: 0.18
Nodes (6): CURRENCIES, editing, form, open, removing, Row

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
Cohesion: 0.08
Nodes (21): props, props, props, props, props, props, props, delegatedProps (+13 more)

### Community 12 - "require-dev"
Cohesion: 0.25
Nodes (8): require-dev, fakerphp/faker, laravel/pail, laravel/pao, laravel/pint, mockery/mockery, nunomaduro/collision, phpunit/phpunit

### Community 13 - "EquityChart.vue"
Cohesion: 0.12
Nodes (14): active, areaPath, box, flowPoints, gridLines, hover, PAD, path (+6 more)

### Community 14 - "setup"
Cohesion: 0.25
Nodes (8): post-root-package-install, setup, composer install, npm install --ignore-scripts, npm run build, @php artisan key:generate, @php artisan migrate --force, @php -r \"file_exists('.env') || copy('.env.example', '.env');\

### Community 15 - "PnlCalendar.vue"
Cohesion: 0.20
Nodes (8): emit, iso(), maxAbs, props, today, WEEKDAYS, weeks, DayStat

### Community 16 - "Admin.vue"
Cohesion: 0.09
Nodes (17): backingUp, Backup, csrf(), editing, gemini, GeminiKey, now, open (+9 more)

### Community 17 - "TestCase"
Cohesion: 0.09
Nodes (10): Illuminate\Foundation\Testing\RefreshDatabase, Illuminate\Foundation\Testing\TestCase, Illuminate\Support\Facades\File, Illuminate\Support\Facades\Http, BackupTest, ErrorPageTest, GeminiKeyTest, RegisterTest (+2 more)

### Community 18 - "AccountStats"
Cohesion: 0.08
Nodes (14): Transaction, AppServiceProvider, AccountStats, Uploads, Carbon\CarbonImmutable, Carbon\CarbonInterface, Illuminate\Http\UploadedFile, Illuminate\Support\Collection (+6 more)

### Community 19 - "dependencies"
Cohesion: 0.11
Nodes (19): class-variance-authority, clsx, @lucide/vue, marked, dependencies, class-variance-authority, clsx, @lucide/vue (+11 more)

### Community 20 - "AnalysisChat.vue"
Cohesion: 0.12
Nodes (20): busy, clear(), close(), closing, confirming, csrf(), draft, error (+12 more)

### Community 21 - "Illuminate\Database\Eloquent\Model"
Cohesion: 0.20
Nodes (4): AccountRule, Illuminate\Database\Eloquent\Attributes\Fillable, Illuminate\Database\Eloquent\Model, Illuminate\Database\Eloquent\Relations\BelongsTo

### Community 22 - "components.json"
Cohesion: 0.12
Nodes (16): aliases, components, composables, lib, ui, utils, iconLibrary, $schema (+8 more)

### Community 23 - "devDependencies"
Cohesion: 0.12
Nodes (17): concurrently, fontaine, laravel-vite-plugin, devDependencies, concurrently, fontaine, laravel-vite-plugin, tailwindcss (+9 more)

### Community 24 - "bootstrap/app.php"
Cohesion: 0.19
Nodes (9): EnsureAdmin, EnsureTrader, RequireAccount, SetCurrentAccount, Closure, Illuminate\Foundation\Application, Illuminate\Foundation\Configuration\Exceptions, Illuminate\Foundation\Configuration\Middleware (+1 more)

### Community 25 - "Tabs.vue"
Cohesion: 0.12
Nodes (11): delegatedProps, emits, forwarded, props, delegatedProps, props, delegatedProps, props (+3 more)

### Community 26 - "Alur import trade dari screenshot"
Cohesion: 0.15
Nodes (15): Alur kerja graphify untuk repo ini, robots.txt mengizinkan seluruh crawler, Alur import trade dari screenshot, AiImportDialog, Urutan pengerjaan 7 fase, Gemini::extractTrade(), Gemini API (gemini-3.5-flash), App\Services\Gemini (+7 more)

### Community 27 - "Dashboard.vue"
Cohesion: 0.20
Nodes (12): frameClass(), frameGap(), frameTop(), Groupable, currency, growthPct, mode, props (+4 more)

### Community 28 - "dialog/index.ts"
Cohesion: 0.08
Nodes (17): emits, forwarded, props, props, delegatedProps, forwardedProps, props, props (+9 more)

### Community 29 - "Rules.vue"
Cohesion: 0.14
Nodes (13): useCurrency(), AmountKey, currency, dailyLoss, dailyTarget, estimate(), form, limit() (+5 more)

### Community 31 - "Calendar.vue"
Cohesion: 0.12
Nodes (15): delegatedProps, props, BadgeVariants, clock(), pnlClass(), currency, dayLots, dayStat (+7 more)

### Community 32 - "input/index.ts"
Cohesion: 0.13
Nodes (11): FEATURES, model, shown, form, props, sisaKunci, confirming, profile (+3 more)

### Community 33 - "Index.vue"
Cohesion: 0.08
Nodes (26): dateTime(), longDate(), price(), apply, blockRange(), currency, dayKey(), detail (+18 more)

### Community 34 - "User"
Cohesion: 0.24
Nodes (4): User, AnnualReport, Illuminate\Foundation\Auth\User, ReportTest

### Community 35 - "Transactions.vue"
Cohesion: 0.10
Nodes (17): monthLabel(), rateCurrency(), toIdr(), currency, form, inIdr(), month, MONTHS (+9 more)

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

### Community 40 - "SetupPicker.vue"
Cohesion: 0.40
Nodes (5): emit, options, props, selected, SETUPS

### Community 41 - "types/index.ts"
Cohesion: 0.16
Nodes (11): pages, props, props, TAG, AccountBrief, CurrentAccount, Direction, PageProps (+3 more)

### Community 43 - "shadcn-vue (reka-ui)"
Cohesion: 0.32
Nodes (8): Tema dark-only, Token warna nfp dark di-flatten ke :root, Utilities .glass / ornamen / hover-lift, PnlCalendar (grid CSS 7 kolom manual), Aturan warna semantik (gold / success / destructive / cyan), shadcn-vue (reka-ui), Tailwind CSS v4 (CSS-first), Waktu disimpan dalam Asia/Jakarta

### Community 44 - "Trade"
Cohesion: 0.12
Nodes (3): Trade, JournalTest, TradeGroupTest

### Community 45 - "Form.vue"
Cohesion: 0.10
Nodes (15): emits, modelValue, props, aiFields, aiPreview, currency, editing, form (+7 more)

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
Cohesion: 0.19
Nodes (3): Account, Illuminate\Database\Eloquent\Relations\HasMany, RuleLimitTest

### Community 54 - "DropdownMenuContent.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 55 - "Input.vue"
Cohesion: 0.50
Nodes (3): emits, modelValue, props

### Community 57 - "Illuminate\Http\RedirectResponse"
Cohesion: 0.18
Nodes (5): AdminController, ProfileController, Illuminate\Database\Eloquent\Relations\HasOne, Illuminate\Http\RedirectResponse, Symfony\Component\HttpFoundation\BinaryFileResponse

### Community 58 - "require"
Cohesion: 0.29
Nodes (7): require, dompdf/dompdf, inertiajs/inertia-laravel, laravel/framework, laravel/octane, laravel/tinker, php

### Community 59 - "draw_icon"
Cohesion: 0.67
Nodes (3): Image, draw_icon(), main()

### Community 60 - "Error.vue"
Cohesion: 0.29
Nodes (4): message, MESSAGES, props, signedIn

### Community 64 - "psr-4"
Cohesion: 0.40
Nodes (5): autoload, psr-4, App\\, Database\\Factories\\, Database\\Seeders\\

### Community 66 - "BackupDatabase"
Cohesion: 0.14
Nodes (6): BackupDatabase, CarbonImmutable, Illuminate\Console\Command, Illuminate\Support\Carbon, Illuminate\Support\Facades\Process, self

### Community 67 - "DialogContent.vue"
Cohesion: 0.25
Nodes (6): delegatedProps, emits, forwarded, props, delegatedProps, props

### Community 69 - "useFormat.ts"
Cohesion: 0.15
Nodes (17): axis, bars, changePct, niceStep(), props, totals, breached, lossPct (+9 more)

### Community 70 - "post-create-project-cmd"
Cohesion: 0.50
Nodes (4): post-create-project-cmd, @php artisan key:generate --ansi, @php artisan migrate --graceful --ansi, @php -r \"file_exists('database/database.sqlite') || touch('database/database.sqlite');\

### Community 80 - "Illuminate\Http\Request"
Cohesion: 0.20
Nodes (6): AccountController, AnalysisController, HandleInertiaRequests, Illuminate\Http\JsonResponse, Illuminate\Http\Request, Inertia\Middleware

### Community 81 - "DropdownMenuCheckboxItem.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 82 - "DropdownMenuSubContent.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 83 - "SelectContent.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 85 - "console.php"
Cohesion: 0.50
Nodes (3): Illuminate\Foundation\Inspiring, Illuminate\Support\Facades\Artisan, Illuminate\Support\Facades\Schedule

### Community 86 - "Controller"
Cohesion: 0.14
Nodes (7): RegisterController, CalendarController, CarbonImmutable, Controller, DashboardController, RuleController, TransactionController

### Community 87 - "Inertia\Response"
Cohesion: 0.22
Nodes (8): Illuminate\Auth\Events\Lockout, Illuminate\Support\Facades\Auth, Illuminate\Support\Facades\RateLimiter, Illuminate\Validation\Rule, Illuminate\Validation\Rules\Password, Illuminate\Validation\ValidationException, Inertia\Inertia, Inertia\Response

### Community 88 - "TradeRequest"
Cohesion: 0.32
Nodes (3): TradeRequest, Illuminate\Contracts\Validation\Validator, Illuminate\Foundation\Http\FormRequest

### Community 89 - "User.php"
Cohesion: 0.14
Nodes (8): UserFactory, Illuminate\Database\Eloquent\Attributes\Hidden, Illuminate\Database\Eloquent\Factories\Factory, Illuminate\Database\Eloquent\Factories\HasFactory, Illuminate\Notifications\Notifiable, Illuminate\Support\Facades\Hash, static, ProfileTest

### Community 90 - "extra"
Cohesion: 0.67
Nodes (3): extra, laravel, dont-discover

### Community 94 - "ReportController.php"
Cohesion: 0.24
Nodes (4): ReportController, Dompdf\Dompdf, Illuminate\Database\Eloquent\Collection, Illuminate\Http\Response

### Community 95 - "Analysis.vue"
Cohesion: 0.14
Nodes (9): html, props, tones, currency, form, PERIODS, props, Breakdown (+1 more)

### Community 96 - "Report.vue"
Cohesion: 0.22
Nodes (7): errors, foreign, form, page, parsedRate, props, today

### Community 97 - "ConfirmDestroy.vue"
Cohesion: 0.40
Nodes (4): code, emit, props, typed

### Community 98 - "DemoSeeder.php"
Cohesion: 0.38
Nodes (3): DatabaseSeeder, DemoSeeder, Illuminate\Database\Seeder

## Ambiguous Edges - Review These
- `robots.txt mengizinkan seluruh crawler` → `REGISTER_TOKEN penjaga pendaftaran mandiri`  [AMBIGUOUS]
  public/robots.txt · relation: conceptually_related_to

## Knowledge Gaps
- **428 isolated node(s):** `$schema`, `style`, `typescript`, `config`, `css` (+423 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `robots.txt mengizinkan seluruh crawler` and `REGISTER_TOKEN penjaga pendaftaran mandiri`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `cn()` connect `utils.ts` to `Separator.vue`, `DialogContent.vue`, `dropdown-menu/index.ts`, `select/index.ts`, `Form.vue`, `DropdownMenuCheckboxItem.vue`, `DropdownMenuSubContent.vue`, `SelectContent.vue`, `DropdownMenuContent.vue`, `Input.vue`, `Tabs.vue`, `dialog/index.ts`, `Progress.vue`, `button/index.ts`, `Calendar.vue`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Why does `User` connect `User` to `BackupDatabase`, `DemoSeeder.php`, `AdminTest`, `Trade`, `TestCase`, `AccountStats`, `TradeImportTest`, `Account`, `Controller`, `Inertia\Response`, `AnalysisChatTest`, `User.php`, `LoginThrottleTest`, `AiAnalysis`, `Illuminate\Http\RedirectResponse`?**
  _High betweenness centrality (0.025) - this node is a cross-community bridge._
- **Why does `Account` connect `Account` to `BackupDatabase`, `DemoSeeder.php`, `User`, `Trade`, `Illuminate\Http\Request`, `TestCase`, `AccountStats`, `TradeImportTest`, `Illuminate\Database\Eloquent\Model`, `Inertia\Response`, `AnalysisChatTest`, `Illuminate\Http\RedirectResponse`, `AiAnalysis`, `ReportController.php`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **What connects `$schema`, `style`, `typescript` to the rest of the system?**
  _428 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `composer.json` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `Illuminate\Database\Migrations\Migration` be split into smaller, more focused modules?**
  _Cohesion score 0.06184012066365008 - nodes in this community are weakly interconnected._