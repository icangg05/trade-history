# Graph Report - trade-history  (2026-08-24)

## Corpus Check
- Corpus is ~39,441 words - fits in a single context window. You may not need a graph.

## Summary
- 1015 nodes · 1717 edges · 80 communities (67 shown, 13 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 44 edges (avg confidence: 0.86)
- Token cost: 109,114 input · 0 output

## Community Hubs (Navigation)
- Account Domain Models
- Transactions & Stats Service
- Composer Package Config
- Database Migrations
- Dashboard Charts & Rule Banner
- Dropdown Menu Primitives
- Button & Confirm Destroy
- Select Primitives
- TypeScript Config
- Composer Scripts
- Vue Bootstrap & PWA Install
- Card UI Primitives
- Table UI Primitives
- Equity Curve Chart
- Controller & Route Registry
- PnL Calendar Component
- Account Controller & Switching
- Gemini Settings & HTTP Client
- Auth & Account Middleware
- Frontend Runtime Dependencies
- Login & Registration Controllers
- Trade Controller CRUD
- shadcn-vue Component Config
- Frontend Build Dependencies
- Markdown & Textarea Rendering
- Tabs UI Primitives
- AI Screenshot Import Design
- Trades Index & Badge
- Dialog Root Primitives
- Trade Form Page
- AI Import Dialog
- Transactions Page & StatCard
- Accounts Page
- Gemini Service
- Upload Storage Service
- Registration Token Tests
- Package Manifest Metadata
- PWA Icon Set
- Trade Data Model Design
- Admin Role Tests
- Trade Import Tests
- Trade Import Controller
- Trade Request Validation
- Dark Theme Design System
- Dialog Content & Overlay
- Dialog Title & Input
- AI Analysis & Stats Design
- Docker App & MySQL Services
- Docker Vite & File Storage
- Account Rules Design
- PWA & Vite Build Design
- Logging Configuration
- Dialog Scroll Content
- Dropdown Checkbox Item
- Dropdown Menu Content
- Dropdown Submenu Content
- Select Content Primitive
- Analysis Controller
- Inertia Request Middleware
- Icon Generation Script
- Dialog Description Primitive
- Dropdown Menu Item
- Dropdown Menu Label
- Progress UI Primitive
- Select Item Primitive
- Separator UI Primitive
- Console Routes
- Inertia Vue Adapter
- Tailwind Vite Plugin
- Node Type Definitions
- Vue Vite Plugin

## God Nodes (most connected - your core abstractions)
1. `cn()` - 52 edges
2. `User` - 29 edges
3. `Account` - 27 edges
4. `Trade` - 26 edges
5. `AccountStats` - 26 edges
6. `Gemini` - 22 edges
7. `GeminiSetting` - 21 edges
8. `JournalTest` - 16 edges
9. `compilerOptions` - 16 edges
10. `Controller` - 15 edges

## Surprising Connections (you probably didn't know these)
- `Penyimpanan bukti transfer privat` --semantically_similar_to--> `Screenshot trade tidak disimpan`  [INFERRED] [semantically similar]
  README.md → RANCANGAN.md
- `robots.txt mengizinkan seluruh crawler` --conceptually_related_to--> `REGISTER_TOKEN penjaga pendaftaran mandiri`  [AMBIGUOUS]
  public/robots.txt → README.md
- `compose service: app (FrankenPHP dev)` --implements--> `FrankenPHP + Laravel Octane (worker mode)`  [EXTRACTED]
  compose.yml → RANCANGAN.md
- `compose service: vite (node:24-slim, one-shot)` --implements--> `Vite 8 (rolldown)`  [EXTRACTED]
  compose.yml → RANCANGAN.md
- `GeminiQuotaTest` --references--> `GeminiSetting`  [EXTRACTED]
  tests/Feature/GeminiQuotaTest.php → app/Models/GeminiSetting.php

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Pipeline import trade dari screenshot** — rancangan_aiimportdialog, rancangan_extracttrade, rancangan_layered_verification, rancangan_traderequest, rancangan_tradeform, rancangan_ai_raw, rancangan_screenshot_not_stored [EXTRACTED 1.00]
- **Design system dark-only** — rancangan_dark_only_theme, rancangan_design_tokens, rancangan_glass_utilities, rancangan_semantic_color_rules, rancangan_typography_mono [EXTRACTED 1.00]
- **Stack dev docker compose** — compose_app_service, compose_mysql_service, compose_vite_service, compose_host_user_mapping, compose_no_env_file, compose_healthcheck_up, compose_storage_bind_mount [EXTRACTED 1.00]
- **PWA / Web App Manifest Icon Set** — public_icons_icon_512_app_icon, public_icons_icon_192_app_icon, public_icons_icon_32_favicon, public_icons_apple_touch_icon_icon, public_icons_maskable_512_maskable_icon, public_icons_maskable_192_maskable_icon [INFERRED 0.95]
- **Maskable-Purpose Icon Variants** — public_icons_maskable_512_maskable_icon, public_icons_maskable_192_maskable_icon, public_icons_maskable_512_safe_zone [INFERRED 0.85]

## Communities (80 total, 13 thin omitted)

### Community 0 - "Account Domain Models"
Cohesion: 0.05
Nodes (22): Account, AccountRule, AiAnalysis, User, UserFactory, DatabaseSeeder, DemoSeeder, Illuminate\Database\Eloquent\Attributes\Fillable (+14 more)

### Community 1 - "Transactions & Stats Service"
Cohesion: 0.10
Nodes (11): TransactionController, Transaction, AppServiceProvider, AccountStats, Uploads, Carbon\CarbonInterface, CarbonImmutable, Illuminate\Support\Collection (+3 more)

### Community 2 - "Composer Package Config"
Cohesion: 0.05
Nodes (42): pestphp/pest-plugin, php-http/discovery, autoload, autoload-dev, psr-4, psr-4, config, allow-plugins (+34 more)

### Community 3 - "Database Migrations"
Cohesion: 0.09
Nodes (4): Illuminate\Database\Migrations\Migration, Illuminate\Database\Schema\Blueprint, Illuminate\Support\Facades\DB, Illuminate\Support\Facades\Schema

### Community 4 - "Dashboard Charts & Rule Banner"
Cohesion: 0.10
Nodes (26): bars, max, props, breached, lossPct, profitPct, props, CurrencyCode (+18 more)

### Community 5 - "Dropdown Menu Primitives"
Cohesion: 0.06
Nodes (22): emits, forwarded, props, props, emits, forwarded, props, delegatedProps (+14 more)

### Community 6 - "Button & Confirm Destroy"
Cohesion: 0.10
Nodes (15): code, emit, props, typed, Props, ButtonVariants, editing, gemini (+7 more)

### Community 7 - "Select Primitives"
Cohesion: 0.07
Nodes (18): emits, forwarded, props, props, props, props, delegatedProps, forwardedProps (+10 more)

### Community 8 - "TypeScript Config"
Cohesion: 0.07
Nodes (26): DOM, DOM.Iterable, ESNext, node, resources/js/**/*.d.ts, resources/js/**/*.ts, resources/js/**/*.vue, vite/client (+18 more)

### Community 9 - "Composer Scripts"
Cohesion: 0.08
Nodes (26): scripts, dev, post-autoload-dump, post-create-project-cmd, post-root-package-install, post-update-cmd, pre-package-uninstall, setup (+18 more)

### Community 10 - "Vue Bootstrap & PWA Install"
Cohesion: 0.10
Nodes (19): AUTH_PAGES, deferred, installed, InstallPromptEvent, isIos(), isStandalone(), listenForInstall(), useInstall() (+11 more)

### Community 11 - "Card UI Primitives"
Cohesion: 0.11
Nodes (11): props, props, props, props, props, props, props, props (+3 more)

### Community 12 - "Table UI Primitives"
Cohesion: 0.13
Nodes (12): props, props, props, props, props, delegatedProps, props, props (+4 more)

### Community 13 - "Equity Curve Chart"
Cohesion: 0.10
Nodes (19): active, areaPath, box, flowPoints, gridLines, hover, PAD, path (+11 more)

### Community 14 - "Controller & Route Registry"
Cohesion: 0.19
Nodes (9): CalendarController, Carbon\CarbonImmutable, Illuminate\Support\Facades\Auth, Illuminate\Support\Facades\Process, Illuminate\Validation\Rule, Illuminate\Validation\Rules\Password, Illuminate\Validation\ValidationException, Inertia\Inertia (+1 more)

### Community 15 - "PnL Calendar Component"
Cohesion: 0.10
Nodes (16): emit, iso(), maxAbs, props, today, WEEKDAYS, weeks, compact() (+8 more)

### Community 16 - "Account Controller & Switching"
Cohesion: 0.23
Nodes (5): AccountController, AdminController, ProfileController, Illuminate\Http\RedirectResponse, Illuminate\Http\Request

### Community 17 - "Gemini Settings & HTTP Client"
Cohesion: 0.13
Nodes (7): GeminiSetting, Illuminate\Http\Client\ConnectionException, Illuminate\Http\Client\RequestException, Illuminate\Support\Facades\Http, Illuminate\Support\Facades\RateLimiter, RuntimeException, GeminiQuotaTest

### Community 18 - "Auth & Account Middleware"
Cohesion: 0.19
Nodes (9): EnsureAdmin, EnsureTrader, RequireAccount, SetCurrentAccount, Closure, Illuminate\Foundation\Application, Illuminate\Foundation\Configuration\Exceptions, Illuminate\Foundation\Configuration\Middleware (+1 more)

### Community 19 - "Frontend Runtime Dependencies"
Cohesion: 0.11
Nodes (19): class-variance-authority, clsx, @lucide/vue, marked, dependencies, class-variance-authority, clsx, @lucide/vue (+11 more)

### Community 20 - "Login & Registration Controllers"
Cohesion: 0.16
Nodes (5): LoginController, RegisterController, Controller, DashboardController, RuleController

### Community 22 - "shadcn-vue Component Config"
Cohesion: 0.12
Nodes (16): aliases, components, composables, lib, ui, utils, iconLibrary, $schema (+8 more)

### Community 23 - "Frontend Build Dependencies"
Cohesion: 0.12
Nodes (17): concurrently, fontaine, laravel-vite-plugin, devDependencies, concurrently, fontaine, laravel-vite-plugin, tailwindcss (+9 more)

### Community 24 - "Markdown & Textarea Rendering"
Cohesion: 0.12
Nodes (11): html, props, emits, modelValue, props, useCurrency(), currency, form (+3 more)

### Community 25 - "Tabs UI Primitives"
Cohesion: 0.12
Nodes (11): delegatedProps, emits, forwarded, props, delegatedProps, props, delegatedProps, props (+3 more)

### Community 26 - "AI Screenshot Import Design"
Cohesion: 0.15
Nodes (15): Alur kerja graphify untuk repo ini, robots.txt mengizinkan seluruh crawler, Alur import trade dari screenshot, AiImportDialog, Urutan pengerjaan 7 fase, Gemini::extractTrade(), Gemini API (gemini-3.5-flash), App\Services\Gemini (+7 more)

### Community 27 - "Trades Index & Badge"
Cohesion: 0.15
Nodes (11): delegatedProps, props, BadgeVariants, price(), apply, currency, filters, Paginated (+3 more)

### Community 28 - "Dialog Root Primitives"
Cohesion: 0.13
Nodes (9): emits, forwarded, props, props, props, confirming, profile, removal (+1 more)

### Community 29 - "Trade Form Page"
Cohesion: 0.14
Nodes (10): aiFields, aiPreview, currency, editing, form, lowConfidence, plannedRr, props (+2 more)

### Community 30 - "AI Import Dialog"
Cohesion: 0.22
Nodes (12): busy, close(), csrf(), emit, error, file, onDrop(), onPaste() (+4 more)

### Community 31 - "Transactions Page & StatCard"
Cohesion: 0.17
Nodes (7): tones, currency, form, open, proofPreview, removing, Row

### Community 32 - "Accounts Page"
Cohesion: 0.17
Nodes (7): CURRENCIES, pnlClass(), editing, form, open, removing, Row

### Community 34 - "Upload Storage Service"
Cohesion: 0.22
Nodes (4): Illuminate\Http\UploadedFile, Illuminate\Support\Facades\Storage, Illuminate\Support\Str, Pdo\Mysql

### Community 35 - "Registration Token Tests"
Cohesion: 0.22
Nodes (4): Illuminate\Foundation\Testing\RefreshDatabase, Illuminate\Foundation\Testing\TestCase, RegisterTest, TestCase

### Community 36 - "Package Manifest Metadata"
Cohesion: 0.20
Nodes (9): @laravel/multiplex, optionalDependencies, @laravel/multiplex, private, $schema, scripts, build, dev (+1 more)

### Community 37 - "PWA Icon Set"
Cohesion: 0.42
Nodes (10): Apple Touch Icon 180 (iOS home screen), App Icon 192 (PWA install/home-screen size), Favicon 32 (browser tab size), Small-Size Legibility Simplification, App Icon 512 (rounded squircle, rising-chart mark), Rising Trend Line Brand Mark, Rounded Squircle Container Treatment, Maskable Icon 192 (full-bleed, adaptive-mask safe) (+2 more)

### Community 38 - "Trade Data Model Design"
Cohesion: 0.20
Nodes (10): Kolom ai_raw (jejak bacaan Gemini), Font self-host via bunny() laravel-vite-plugin, Mata uang akun USD / USC / IDR, Inertia v3 + Vue 3 (script setup, TS), Laravel 13 monolith, price() di useFormat.ts, Kolom RR menampilkan R hasil dan R rencana, Screenshot trade tidak disimpan (+2 more)

### Community 41 - "Trade Import Controller"
Cohesion: 0.36
Nodes (4): TradeImportController, Illuminate\Http\JsonResponse, Illuminate\Support\Facades\Log, Throwable

### Community 42 - "Trade Request Validation"
Cohesion: 0.32
Nodes (3): TradeRequest, Illuminate\Contracts\Validation\Validator, Illuminate\Foundation\Http\FormRequest

### Community 43 - "Dark Theme Design System"
Cohesion: 0.32
Nodes (8): Tema dark-only, Token warna nfp dark di-flatten ke :root, Utilities .glass / ornamen / hover-lift, PnlCalendar (grid CSS 7 kolom manual), Aturan warna semantik (gold / success / destructive / cyan), shadcn-vue (reka-ui), Tailwind CSS v4 (CSS-first), Waktu disimpan dalam Asia/Jakarta

### Community 44 - "Dialog Content & Overlay"
Cohesion: 0.25
Nodes (6): delegatedProps, emits, forwarded, props, delegatedProps, props

### Community 45 - "Dialog Title & Input"
Cohesion: 0.21
Nodes (6): delegatedProps, forwardedProps, props, emits, modelValue, props

### Community 46 - "AI Analysis & Stats Design"
Cohesion: 0.38
Nodes (7): App\Services\AccountStats, Tabel ai_analyses (cache hasil Gemini), Alur analisa AI berbasis statistik, Gemini::analyze(), EquityChart.vue (SVG murni), MonthlyPnlChart.vue (SVG murni), Tanpa tabel ledger/snapshot saldo

### Community 47 - "Docker App & MySQL Services"
Cohesion: 0.33
Nodes (6): compose service: app (FrankenPHP dev), Healthcheck app memakai route /up, compose service: mysql 8.4, Tanpa env_file pada service app, FrankenPHP + Laravel Octane (worker mode), MySQL 8.4

### Community 48 - "Docker Vite & File Storage"
Cohesion: 0.33
Nodes (6): Kontainer berjalan sebagai UID/GID host, Bind mount ./storage/app, compose service: vite (node:24-slim, one-shot), Tabel transactions (deposit/withdrawal), Penyimpanan bukti transfer privat, App\Services\Uploads (bukti transfer di disk privat)

### Community 49 - "Account Rules Design"
Cohesion: 0.40
Nodes (6): Tabel account_rules (kolom eksplisit, 1:1 akun), Account switcher di header, Tabel accounts, Aturan trading tidak memblokir input, RuleStatusBanner, Middleware SetCurrentAccount

### Community 50 - "PWA & Vite Build Design"
Cohesion: 0.33
Nodes (6): Menu "Pasang aplikasi" + manifest.id, PWA (manifest + service worker tulis tangan), public/sw.js (cache aset build saja), TypeScript dipatok ^5.9, Vite 8 (rolldown), scripts/make-icons.py (generator ikon PWA)

### Community 51 - "Logging Configuration"
Cohesion: 0.40
Nodes (4): Monolog\Handler\NullHandler, Monolog\Handler\StreamHandler, Monolog\Handler\SyslogUdpHandler, Monolog\Processor\PsrLogMessageProcessor

### Community 52 - "Dialog Scroll Content"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 53 - "Dropdown Checkbox Item"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 54 - "Dropdown Menu Content"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 55 - "Dropdown Submenu Content"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 56 - "Select Content Primitive"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 59 - "Icon Generation Script"
Cohesion: 0.67
Nodes (3): Image, draw_icon(), main()

### Community 60 - "Dialog Description Primitive"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 61 - "Dropdown Menu Item"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 62 - "Dropdown Menu Label"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 64 - "Select Item Primitive"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

## Ambiguous Edges - Review These
- `REGISTER_TOKEN penjaga pendaftaran mandiri` → `robots.txt mengizinkan seluruh crawler`  [AMBIGUOUS]
  public/robots.txt · relation: conceptually_related_to

## Knowledge Gaps
- **362 isolated node(s):** `$schema`, `style`, `typescript`, `config`, `css` (+357 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `REGISTER_TOKEN penjaga pendaftaran mandiri` and `robots.txt mengizinkan seluruh crawler`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `cn()` connect `Table UI Primitives` to `Dropdown Menu Primitives`, `Button & Confirm Destroy`, `Select Primitives`, `Card UI Primitives`, `Markdown & Textarea Rendering`, `Tabs UI Primitives`, `Trades Index & Badge`, `Dialog Content & Overlay`, `Dialog Title & Input`, `Dialog Scroll Content`, `Dropdown Checkbox Item`, `Dropdown Menu Content`, `Dropdown Submenu Content`, `Select Content Primitive`, `Dialog Description Primitive`, `Dropdown Menu Item`, `Dropdown Menu Label`, `Progress UI Primitive`, `Select Item Primitive`, `Separator UI Primitive`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Why does `User` connect `Account Domain Models` to `Upload Storage Service`, `Admin Role Tests`, `Trade Import Tests`, `Controller & Route Registry`, `Account Controller & Switching`, `Gemini Settings & HTTP Client`, `Login & Registration Controllers`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Why does `Account` connect `Account Domain Models` to `Transactions & Stats Service`, `Upload Storage Service`, `Trade Import Tests`, `Controller & Route Registry`, `Account Controller & Switching`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **What connects `$schema`, `style`, `typescript` to the rest of the system?**
  _362 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Account Domain Models` be split into smaller, more focused modules?**
  _Cohesion score 0.051577152600170505 - nodes in this community are weakly interconnected._
- **Should `Transactions & Stats Service` be split into smaller, more focused modules?**
  _Cohesion score 0.09725158562367865 - nodes in this community are weakly interconnected._