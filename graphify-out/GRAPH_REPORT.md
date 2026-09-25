# Graph Report - trade-history  (2026-09-25)

## Corpus Check
- 292 files · ~112,567 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 63 file(s) not represented in the graph (top: (none) 23, .xml 10, .ttf 7)

## Summary
- 2691 nodes · 4876 edges · 147 communities (113 shown, 34 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 41 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `437b4099`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- stats.dart
- GeminiKey
- composer.json
- Illuminate\Database\Schema\Blueprint
- Illuminate\Http\JsonResponse
- reka-ui
- Illuminate\Http\Request
- select/index.ts
- compilerOptions
- scripts
- AppLayout.vue
- vue
- require-dev
- useFormat.ts
- common.dart
- EquityChart.vue
- Admin.vue
- TestCase
- AccountStats
- dependencies
- AnalysisChat.vue
- ReportController.php
- components.json
- devDependencies
- bootstrap/app.php
- Tabs.vue
- Alur import trade dari screenshot
- journal.dart
- @vueuse/core
- @lucide/vue
- DropdownMenuContent.vue
- Calendar.vue
- Accounts.vue
- Index.vue
- ReportTest
- Transactions.vue
- package.json
- App Icon 512 (rounded squircle, rising-chart mark)
- Tabel trades
- trade.dart
- TransactionController.php
- trade_form_screen.dart
- transaction_form.dart
- shadcn-vue (reka-ui)
- JournalTest
- SetupPicker.vue
- App\Services\AccountStats
- compose service: app (FrankenPHP dev)
- Penyimpanan bukti transfer privat
- Tabel accounts
- PWA (manifest + service worker tulis tangan)
- logging.php
- config
- trades_screen.dart
- User
- support.dart
- Account
- Illuminate\Http\RedirectResponse
- require
- make-icons.py
- rules_screen.dart
- Hashid
- format.dart
- StatelessWidget
- psr-4
- Rules.vue
- DropdownMenuRadioItem.vue
- DialogContent.vue
- dashboard_screen.dart
- Controller
- session.dart
- artisan
- RuleLimitTest
- chat_screen.dart
- DemoSeeder.php
- theme.dart
- journal_api.dart
- Transaction
- Badge.vue
- TradeController.php
- extra
- TradeRequest
- calendar_screen.dart
- transactions_screen.dart
- app.dart
- trade_widgets.dart
- api_client.dart
- Trade
- types/index.ts
- DialogDescription.vue
- TradeImportTest
- report_screen.dart
- accounts_screen.dart
- account.dart
- trade_filters_sheet.dart
- analysis_screen.dart
- login_screen.dart
- .application
- profile_screen.dart
- trade_detail.dart
- revisionProvider
- Illuminate\Database\Eloquent\Model
- charts.dart
- models_test.dart
- setup_picker.dart
- ApiTest
- DialogTitle.vue
- SelectScrollDownButton.vue
- web.php
- TradeGroupTest
- Illuminate\Support\Collection
- 2026_08_24_000006_create_admin_and_gemini_settings.php
- json.dart
- AdminTest
- Gemini
- Illuminate\Database\Migrations\Migration
- Illuminate\Support\Facades\Schema
- Trade History — mobile
- BackupDatabase
- 0001_01_01_000001_create_cache_table.php
- 2026_08_24_000007_add_limits_to_gemini_settings.php
- 2026_08_25_000009_widen_trades_setup.php
- 2026_08_26_000010_add_group_id_to_trades.php
- 2026_08_26_000011_add_pre_group_to_trades.php
- 2026_08_28_000012_drop_pips_and_tags_from_trades.php
- 2026_08_29_000013_add_rate_idr_to_transactions.php
- 2026_08_29_000014_add_account_number_to_accounts.php
- 2026_08_30_000015_require_trade_result.php
- DropdownMenuSubContent.vue
- 2026_08_24_000005_create_ai_analyses_table.php
- 2026_09_25_000016_create_personal_access_tokens_table.php
- autoload-dev
- FlutterActivity
- home_user_trade_history_mobile_ios_runner_generatedpluginregistrant_h
- LaunchImage.imageset/README.md
- TradeFilters

## God Nodes (most connected - your core abstractions)
1. `vue` - 81 edges
2. `User` - 69 edges
3. `Account` - 59 edges
4. `cn()` - 52 edges
5. `Trade` - 48 edges
6. `AccountStats` - 47 edges
7. `reka-ui` - 44 edges
8. `@vueuse/core` - 36 edges
9. `TestCase` - 36 edges
10. `@lucide/vue` - 33 edges

## Surprising Connections (you probably didn't know these)
- `Penyimpanan bukti transfer privat` --semantically_similar_to--> `Screenshot trade tidak disimpan`  [INFERRED] [semantically similar]
  README.md → RANCANGAN.md
- `robots.txt mengizinkan seluruh crawler` --conceptually_related_to--> `REGISTER_TOKEN penjaga pendaftaran mandiri`  [AMBIGUOUS]
  public/robots.txt → README.md
- `compose service: app (FrankenPHP dev)` --implements--> `FrankenPHP + Laravel Octane (worker mode)`  [EXTRACTED]
  compose.yml → RANCANGAN.md
- `compose service: vite (node:24-slim, one-shot)` --implements--> `Vite 8 (rolldown)`  [EXTRACTED]
  compose.yml → RANCANGAN.md
- `{closure#14}()` --references--> `Trade`  [EXTRACTED]
  app/Http/Controllers/TradeController.php → app/Models/Trade.php

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Pipeline import trade dari screenshot** — rancangan_aiimportdialog, rancangan_extracttrade, rancangan_layered_verification, rancangan_traderequest, rancangan_tradeform, rancangan_ai_raw, rancangan_screenshot_not_stored [EXTRACTED 1.00]
- **Stack dev docker compose** — compose_app_service, compose_mysql_service, compose_vite_service, compose_host_user_mapping, compose_no_env_file, compose_healthcheck_up, compose_storage_bind_mount [EXTRACTED 1.00]
- **Design system dark-only** — rancangan_dark_only_theme, rancangan_design_tokens, rancangan_glass_utilities, rancangan_semantic_color_rules, rancangan_typography_mono [EXTRACTED 1.00]
- **Maskable-Purpose Icon Variants** — public_icons_maskable_512_maskable_icon, public_icons_maskable_192_maskable_icon, public_icons_maskable_512_safe_zone [INFERRED 0.85]
- **PWA / Web App Manifest Icon Set** — public_icons_icon_512_app_icon, public_icons_icon_192_app_icon, public_icons_icon_32_favicon, public_icons_apple_touch_icon_icon, public_icons_maskable_512_maskable_icon, public_icons_maskable_192_maskable_icon [INFERRED 0.95]

## Communities (147 total, 34 thin omitted)

### Community 0 - "stats.dart"
Cohesion: 0.03
Nodes (66): avgLoss, avgRrPlanned, avgRrRealized, avgWin, balance, breached, _breakdown, BreakdownRow (+58 more)

### Community 1 - "GeminiKey"
Cohesion: 0.09
Nodes (7): {closure#2}(), GeminiKey, Illuminate\Http\Client\ConnectionException, Illuminate\Http\Client\RequestException, Illuminate\Support\Facades\Http, self, AnalysisTest

### Community 2 - "composer.json"
Cohesion: 0.22
Nodes (8): description, keywords, license, minimum-stability, name, prefer-stable, $schema, type

### Community 3 - "Illuminate\Database\Schema\Blueprint"
Cohesion: 0.23
Nodes (7): {closure#1}(), {closure#2}(), {closure#3}(), {closure#1}(), {closure#2}(), {closure#3}(), Illuminate\Database\Schema\Blueprint

### Community 4 - "Illuminate\Http\JsonResponse"
Cohesion: 0.17
Nodes (4): AuthController, {closure#15}(), TradeController, Illuminate\Http\JsonResponse

### Community 5 - "reka-ui"
Cohesion: 0.06
Nodes (28): reka-ui, emits, forwarded, props, delegatedProps, emits, forwarded, props (+20 more)

### Community 6 - "Illuminate\Http\Request"
Cohesion: 0.13
Nodes (10): AccountController, AnalysisController, {closure#1}(), DashboardController, RuleController, AiAnalysis, Period, Carbon\CarbonImmutable (+2 more)

### Community 7 - "select/index.ts"
Cohesion: 0.07
Nodes (20): resources_js_components_ui_select_index_selectscrolldownbutton, resources_js_components_ui_select_index_selectscrollupbutton, emits, forwarded, props, delegatedProps, emits, forwarded (+12 more)

### Community 8 - "compilerOptions"
Cohesion: 0.11
Nodes (17): compilerOptions, allowJs, baseUrl, esModuleInterop, isolatedModules, jsx, lib, module (+9 more)

### Community 9 - "scripts"
Cohesion: 0.22
Nodes (9): scripts, dev, post-autoload-dump, post-create-project-cmd, post-root-package-install, post-update-cmd, pre-package-uninstall, setup (+1 more)

### Community 10 - "AppLayout.vue"
Cohesion: 0.08
Nodes (27): resources_css_app, BARE_PAGES, resources_js_components_ui_dropdown_menu_index_dropdownmenu, resources_js_components_ui_dropdown_menu_index_dropdownmenucontent, resources_js_components_ui_dropdown_menu_index_dropdownmenuitem, resources_js_components_ui_dropdown_menu_index_dropdownmenulabel, resources_js_components_ui_dropdown_menu_index_dropdownmenuseparator, resources_js_components_ui_dropdown_menu_index_dropdownmenutrigger (+19 more)

### Community 11 - "vue"
Cohesion: 0.09
Nodes (25): vue, props, props, props, props, props, props, props (+17 more)

### Community 12 - "require-dev"
Cohesion: 0.25
Nodes (8): require-dev, fakerphp/faker, laravel/pail, laravel/pao, laravel/pint, mockery/mockery, nunomaduro/collision, phpunit/phpunit

### Community 13 - "useFormat.ts"
Cohesion: 0.07
Nodes (39): axis, bars, changePct, niceStep(), props, totals, breached, lossPct (+31 more)

### Community 14 - "common.dart"
Cohesion: 0.05
Nodes (40): AsyncValue, Color get, EdgeInsetsGeometry, IconData?, action, borderColor, build, busy (+32 more)

### Community 15 - "EquityChart.vue"
Cohesion: 0.12
Nodes (15): active, areaPath, box, flowPoints, gridLines, hover, PAD, path (+7 more)

### Community 16 - "Admin.vue"
Cohesion: 0.09
Nodes (17): backingUp, Backup, csrf(), editing, gemini, GeminiKey, now, open (+9 more)

### Community 17 - "TestCase"
Cohesion: 0.08
Nodes (10): Illuminate\Foundation\Testing\RefreshDatabase, Illuminate\Foundation\Testing\TestCase, Illuminate\Support\Facades\File, BackupTest, ErrorPageTest, FlashTest, GeminiKeyTest, LoginThrottleTest (+2 more)

### Community 18 - "AccountStats"
Cohesion: 0.21
Nodes (3): {closure#1}(), AccountStats, Carbon\CarbonInterface

### Community 19 - "dependencies"
Cohesion: 0.18
Nodes (11): dependencies, class-variance-authority, clsx, @inertiajs/vue3, @lucide/vue, marked, reka-ui, tailwind-merge (+3 more)

### Community 20 - "AnalysisChat.vue"
Cohesion: 0.12
Nodes (21): @inertiajs/vue3, busy, clear(), close(), closing, confirming, csrf(), draft (+13 more)

### Community 21 - "ReportController.php"
Cohesion: 0.14
Nodes (6): ReportController, Dompdf\Dompdf, Illuminate\Database\Eloquent\Collection, Illuminate\Http\Response, Illuminate\Support\Str, Pdo\Mysql

### Community 22 - "components.json"
Cohesion: 0.12
Nodes (16): aliases, components, composables, lib, ui, utils, iconLibrary, $schema (+8 more)

### Community 23 - "devDependencies"
Cohesion: 0.17
Nodes (12): devDependencies, concurrently, fontaine, laravel-vite-plugin, tailwindcss, @tailwindcss/vite, tw-animate-css, @types/node (+4 more)

### Community 24 - "bootstrap/app.php"
Cohesion: 0.09
Nodes (20): EnsureAdmin, EnsureTrader, HandleInertiaRequests, RequireAccount, SetCurrentAccount, UseRouteAccount, {closure#1}(), {closure#2}() (+12 more)

### Community 25 - "Tabs.vue"
Cohesion: 0.12
Nodes (11): delegatedProps, emits, forwarded, props, delegatedProps, props, delegatedProps, props (+3 more)

### Community 26 - "Alur import trade dari screenshot"
Cohesion: 0.15
Nodes (15): Alur kerja graphify untuk repo ini, robots.txt mengizinkan seluruh crawler, Alur import trade dari screenshot, AiImportDialog, Urutan pengerjaan 7 fase, Gemini::extractTrade(), Gemini API (gemini-3.5-flash), App\Services\Gemini (+7 more)

### Community 27 - "journal.dart"
Cohesion: 0.03
Nodes (58): accounts, aiEnabled, allowedSessions, amount, analysis, AnalysisPage, analyzedAt, balance (+50 more)

### Community 28 - "@vueuse/core"
Cohesion: 0.08
Nodes (16): @vueuse/core, delegatedProps, emits, forwarded, props, delegatedProps, props, delegatedProps (+8 more)

### Community 29 - "@lucide/vue"
Cohesion: 0.08
Nodes (25): @lucide/vue, FEATURES, model, shown, Props, resources_js_components_ui_button_index_button, ButtonVariants, props (+17 more)

### Community 30 - "DropdownMenuContent.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 31 - "Calendar.vue"
Cohesion: 0.08
Nodes (25): emit, iso(), maxAbs, props, today, WEEKDAYS, weeks, clock() (+17 more)

### Community 32 - "Accounts.vue"
Cohesion: 0.05
Nodes (40): busy, close(), csrf(), emit, error, file, onDrop(), onPaste() (+32 more)

### Community 33 - "Index.vue"
Cohesion: 0.07
Nodes (28): frameClass(), frameGap(), frameTop(), Groupable, activeFilters, apply, blockRange(), currency (+20 more)

### Community 35 - "Transactions.vue"
Cohesion: 0.06
Nodes (29): resources_js_components_ui_select_index_select, resources_js_components_ui_select_index_selectcontent, resources_js_components_ui_select_index_selectitem, resources_js_components_ui_select_index_selecttrigger, resources_js_components_ui_select_index_selectvalue, monthLabel(), toIdr(), errors (+21 more)

### Community 36 - "package.json"
Cohesion: 0.07
Nodes (27): optionalDependencies, @laravel/multiplex, private, $schema, scripts, build, dev, type (+19 more)

### Community 37 - "App Icon 512 (rounded squircle, rising-chart mark)"
Cohesion: 0.42
Nodes (10): Apple Touch Icon 180 (iOS home screen), App Icon 192 (PWA install/home-screen size), Favicon 32 (browser tab size), Small-Size Legibility Simplification, App Icon 512 (rounded squircle, rising-chart mark), Rising Trend Line Brand Mark, Rounded Squircle Container Treatment, Maskable Icon 192 (full-bleed, adaptive-mask safe) (+2 more)

### Community 38 - "Tabel trades"
Cohesion: 0.20
Nodes (10): Kolom ai_raw (jejak bacaan Gemini), Font self-host via bunny() laravel-vite-plugin, Mata uang akun USD / USC / IDR, Inertia v3 + Vue 3 (script setup, TS), Laravel 13 monolith, price() di useFormat.ts, Kolom RR menampilkan R hasil dan R rencana, Screenshot trade tidak disimpan (+2 more)

### Community 39 - "trade.dart"
Cohesion: 0.04
Nodes (45): DateTime get, int get, active, aiRaw, closedAt, daily, data, day (+37 more)

### Community 40 - "TransactionController.php"
Cohesion: 0.19
Nodes (3): TransactionController, Uploads, Symfony\Component\HttpFoundation\StreamedResponse

### Community 41 - "trade_form_screen.dart"
Cohesion: 0.05
Nodes (42): ai_import_sheet.dart, double get, account, aiEnabled, _aiFields, _aiPreview, _aiRaw, _badge (+34 more)

### Community 42 - "transaction_form.dart"
Cohesion: 0.05
Nodes (38): dart:typed_data, account, AiImport, build, _busy, _bytes, createState, _error (+30 more)

### Community 43 - "shadcn-vue (reka-ui)"
Cohesion: 0.32
Nodes (8): Tema dark-only, Token warna nfp dark di-flatten ke :root, Utilities .glass / ornamen / hover-lift, PnlCalendar (grid CSS 7 kolom manual), Aturan warna semantik (gold / success / destructive / cyan), shadcn-vue (reka-ui), Tailwind CSS v4 (CSS-first), Waktu disimpan dalam Asia/Jakarta

### Community 45 - "SetupPicker.vue"
Cohesion: 0.40
Nodes (5): emit, options, props, selected, SETUPS

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

### Community 53 - "trades_screen.dart"
Cohesion: 0.06
Nodes (37): append, _block, createState, currency, daily, day, dispose, _filters (+29 more)

### Community 54 - "User"
Cohesion: 0.09
Nodes (14): {closure#1}(), {closure#1}(), User, UserFactory, Illuminate\Database\Eloquent\Attributes\Hidden, Illuminate\Database\Eloquent\Factories\Factory, Illuminate\Database\Eloquent\Factories\HasFactory, Illuminate\Foundation\Auth\User (+6 more)

### Community 55 - "support.dart"
Cohesion: 0.06
Nodes (36): app.dart, dart:convert, HttpClientAdapter, initializeDateFormatting, main, prefs, main, body (+28 more)

### Community 56 - "Account"
Cohesion: 0.11
Nodes (6): {closure#1}(), Account, Illuminate\Database\Eloquent\Relations\HasMany, Illuminate\Http\UploadedFile, Illuminate\Support\Facades\Storage, AnalysisChatTest

### Community 57 - "Illuminate\Http\RedirectResponse"
Cohesion: 0.14
Nodes (6): AdminController, ProfileController, Illuminate\Http\RedirectResponse, Illuminate\Validation\Rule, Laravel\Sanctum\PersonalAccessToken, Symfony\Component\HttpFoundation\BinaryFileResponse

### Community 58 - "require"
Cohesion: 0.20
Nodes (9): require, dompdf/dompdf, hashids/hashids, inertiajs/inertia-laravel, laravel/framework, laravel/octane, laravel/sanctum, laravel/tinker (+1 more)

### Community 59 - "make-icons.py"
Cohesion: 0.33
Nodes (5): Image, pil, draw_icon(), main(), Generate PWA icons: kurva naik emas di atas latar gelap aplikasi. Jalankan…

### Community 60 - "rules_screen.dart"
Cohesion: 0.06
Nodes (34): account, _allowed, build, _busy, _controllers, createState, _currency, dispose (+26 more)

### Community 61 - "Hashid"
Cohesion: 0.23
Nodes (4): {closure#3}(), HasHashid, Hashid, Hashids\Hashids

### Community 62 - "format.dart"
Cohesion: 0.06
Nodes (33): amount, clock, compact, currencies, currency, dateTime, _digits, _fixed (+25 more)

### Community 63 - "StatelessWidget"
Cohesion: 0.11
Nodes (19): _Pill, _Cell, _DaySheet, _Grid, _DayHeader, AsyncView, BusyButton, Caption (+11 more)

### Community 64 - "psr-4"
Cohesion: 0.40
Nodes (5): autoload, psr-4, App\\, Database\\Factories\\, Database\\Seeders\\

### Community 65 - "Rules.vue"
Cohesion: 0.11
Nodes (16): marked, html, props, resources_js_components_ui_textarea_index_textarea, AmountKey, currency, dailyLoss, dailyTarget (+8 more)

### Community 66 - "DropdownMenuRadioItem.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 67 - "DialogContent.vue"
Cohesion: 0.25
Nodes (6): delegatedProps, emits, forwarded, props, delegatedProps, props

### Community 68 - "dashboard_screen.dart"
Cohesion: 0.06
Nodes (34): charts.dart, Color, ../core/format.dart, build, _content, createState, _cumulative, dashboardProvider (+26 more)

### Community 69 - "Controller"
Cohesion: 0.11
Nodes (9): LoginController, RegisterController, Controller, RegisterRequest, Illuminate\Auth\Events\Lockout, Illuminate\Support\Facades\Auth, Illuminate\Support\Facades\RateLimiter, Illuminate\Validation\ValidationException (+1 more)

### Community 70 - "session.dart"
Cohesion: 0.08
Nodes (34): FlutterSecureStorage, int?, journal_api.dart, JournalApi, _accountKey, apiClientProvider, build, bump (+26 more)

### Community 80 - "chat_screen.dart"
Cohesion: 0.08
Nodes (25): analysis_screen.dart, dart:async, _account, _bubble, _busy, _charsPerSecond, _clear, _controller (+17 more)

### Community 81 - "DemoSeeder.php"
Cohesion: 0.32
Nodes (3): DatabaseSeeder, DemoSeeder, Illuminate\Database\Seeder

### Community 82 - "theme.dart"
Cohesion: 0.06
Nodes (30): accent, accentForeground, AppColors, background, base, border, buildTheme, card (+22 more)

### Community 83 - "journal_api.dart"
Cohesion: 0.06
Nodes (30): accounts, analysis, calendar, chat, client, dashboard, deleteAccount, deleteProfile (+22 more)

### Community 84 - "Transaction"
Cohesion: 0.15
Nodes (8): {closure#4}(), Transaction, {closure#1}(), {closure#2}(), {closure#4}(), {closure#5}(), {closure#9}(), Illuminate\Support\Facades\URL

### Community 85 - "Badge.vue"
Cohesion: 0.40
Nodes (4): class-variance-authority, delegatedProps, props, BadgeVariants

### Community 86 - "TradeController.php"
Cohesion: 0.09
Nodes (4): {closure#12}(), {closure#13}(), {closure#14}(), {closure#9}()

### Community 87 - "extra"
Cohesion: 0.67
Nodes (3): extra, laravel, dont-discover

### Community 88 - "TradeRequest"
Cohesion: 0.24
Nodes (6): {closure#1}(), {closure#1}(), TradeRequest, Illuminate\Contracts\Validation\Validator, Illuminate\Foundation\Http\FormRequest, Illuminate\Validation\Rules\Password

### Community 89 - "calendar_screen.dart"
Cohesion: 0.07
Nodes (28): DayStat?, account, build, calendarProvider, CalendarScreen, _CalendarScreenState, _content, createState (+20 more)

### Community 91 - "transactions_screen.dart"
Cohesion: 0.08
Nodes (27): AccountBrief, AsyncNotifier, account, _content, createState, first, FundsController, FundsList (+19 more)

### Community 92 - "app.dart"
Cohesion: 0.07
Nodes (27): features/accounts/accounts_screen.dart, features/analysis/analysis_screen.dart, features/analysis/chat_screen.dart, features/auth/login_screen.dart, features/auth/register_screen.dart, features/calendar/calendar_screen.dart, features/dashboard/dashboard_screen.dart, features/more/more_screen.dart (+19 more)

### Community 93 - "trade_widgets.dart"
Cohesion: 0.07
Nodes (26): build, currency, dimmed, direction, first, group, groupFrame, groupGap (+18 more)

### Community 94 - "api_client.dart"
Cohesion: 0.08
Nodes (25): Dio, json.dart, ApiClient, _body, _clean, delete, dio, download (+17 more)

### Community 95 - "Trade"
Cohesion: 0.13
Nodes (13): {closure#1}(), {closure#1}(), Trade, {closure#11}(), {closure#12}(), {closure#13}(), {closure#14}(), {closure#15}() (+5 more)

### Community 96 - "types/index.ts"
Cohesion: 0.09
Nodes (20): pages, props, props, TAG, back(), message, MESSAGES, props (+12 more)

### Community 97 - "DialogDescription.vue"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 99 - "report_screen.dart"
Cohesion: 0.09
Nodes (24): dart:io, _address, build, _busy, createState, dispose, _endOfYear, _errors (+16 more)

### Community 100 - "accounts_screen.dart"
Cohesion: 0.07
Nodes (36): common.dart, ConsumerWidget, ../data/session.dart, DateTime, currentAccountProvider, accountsProvider, AccountsScreen, _archived (+28 more)

### Community 102 - "account.dart"
Cohesion: 0.08
Nodes (23): ../core/json.dart, AccountBrief, accountNumber, AccountRow, accounts, AccountsPage, AccountTotal, balance (+15 more)

### Community 103 - "trade_filters_sheet.dart"
Cohesion: 0.08
Nodes (26): _Thinking, _ThinkingState, build, _choices, _copy, createState, _dateButton, dispose (+18 more)

### Community 104 - "analysis_screen.dart"
Cohesion: 0.12
Nodes (18): ../dashboard/dashboard_screen.dart, _aiCard, analysisProvider, AnalysisScreen, _AnalysisScreenState, _Breakdown, build, _content (+10 more)

### Community 105 - "login_screen.dart"
Cohesion: 0.06
Nodes (38): ../core/api_client.dart, List, login_screen.dart, serverProvider, AuthShell, build, _busy, _canRegisterProvider (+30 more)

### Community 106 - ".application"
Cohesion: 0.11
Nodes (14): Any, Bool, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate (+6 more)

### Community 107 - "profile_screen.dart"
Cohesion: 0.07
Nodes (29): ../core/theme.dart, Map, meProvider, sessionProvider, build, MoreScreen, accountCount, build (+21 more)

### Community 108 - "trade_detail.dart"
Cohesion: 0.10
Nodes (20): bool get, account, build, _busy, _complete, _content, createState, currency (+12 more)

### Community 109 - "revisionProvider"
Cohesion: 0.09
Nodes (35): ConsumerState, ConsumerStatefulWidget, journalProvider, revisionProvider, selectedAccountProvider, _AccountForm, _AccountFormState, _after (+27 more)

### Community 110 - "Illuminate\Database\Eloquent\Model"
Cohesion: 0.17
Nodes (5): AccountRule, Illuminate\Database\Eloquent\Attributes\Fillable, Illuminate\Database\Eloquent\Model, Illuminate\Database\Eloquent\Relations\BelongsTo, Illuminate\Database\Eloquent\Relations\HasOne

### Community 111 - "charts.dart"
Cohesion: 0.11
Nodes (17): dart:math, double?, base, build, currency, data, EquityChart, height (+9 more)

### Community 112 - "models_test.dart"
Cohesion: 0.11
Nodes (17): Exception, FilledButton, ApiException, main, openMore, openTab, main, main (+9 more)

### Community 113 - "setup_picker.dart"
Cohesion: 0.20
Nodes (9): build, dense, enabled, kSetups, onChanged, SetupPicker, splitSetup, value (+1 more)

### Community 115 - "DialogTitle.vue"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 116 - "SelectScrollDownButton.vue"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 117 - "web.php"
Cohesion: 0.13
Nodes (4): CalendarController, CarbonImmutable, TradeImportController, Route /

### Community 119 - "Illuminate\Support\Collection"
Cohesion: 0.11
Nodes (9): AppServiceProvider, {closure#1}(), {closure#2}(), {closure#5}(), {closure#17}(), {closure#4}(), {closure#8}(), Illuminate\Support\Collection (+1 more)

### Community 120 - "2026_08_24_000006_create_admin_and_gemini_settings.php"
Cohesion: 0.17
Nodes (6): {closure#1}(), {closure#2}(), {closure#3}(), {closure#1}(), {closure#2}(), Illuminate\Support\Facades\DB

### Community 121 - "json.dart"
Cohesion: 0.18
Nodes (10): Json, list, map, strings, toDouble, toDoubleOrNull, toInt, toIntOrNull (+2 more)

### Community 123 - "Gemini"
Cohesion: 0.20
Nodes (3): Gemini, Illuminate\Support\Facades\Log, RuntimeException

### Community 125 - "Illuminate\Database\Migrations\Migration"
Cohesion: 0.22
Nodes (3): {closure#1}(), {closure#1}(), Illuminate\Database\Migrations\Migration

### Community 126 - "Illuminate\Support\Facades\Schema"
Cohesion: 0.22
Nodes (3): {closure#1}(), {closure#1}(), Illuminate\Support\Facades\Schema

### Community 129 - "Trade History — mobile"
Cohesion: 0.33
Nodes (5): Catatan, Menjalankan, Paket, Peta kode, Trade History — mobile

### Community 130 - "BackupDatabase"
Cohesion: 0.13
Nodes (7): BackupDatabase, Illuminate\Console\Command, Illuminate\Foundation\Inspiring, Illuminate\Support\Carbon, Illuminate\Support\Facades\Artisan, Illuminate\Support\Facades\Process, Illuminate\Support\Facades\Schedule

### Community 142 - "DropdownMenuSubContent.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 147 - "autoload-dev"
Cohesion: 0.67
Nodes (3): autoload-dev, psr-4, Tests\\

## Ambiguous Edges - Review These
- `robots.txt mengizinkan seluruh crawler` → `REGISTER_TOKEN penjaga pendaftaran mandiri`  [AMBIGUOUS]
  public/robots.txt · relation: conceptually_related_to

## Knowledge Gaps
- **1173 isolated node(s):** `$schema`, `style`, `typescript`, `config`, `css` (+1168 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1529 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **34 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `robots.txt mengizinkan seluruh crawler` and `REGISTER_TOKEN penjaga pendaftaran mandiri`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `User` connect `User` to `GeminiKey`, `ReportTest`, `TradeImportTest`, `Illuminate\Http\JsonResponse`, `Controller`, `JournalTest`, `RuleLimitTest`, `DemoSeeder.php`, `ApiTest`, `TestCase`, `TradeGroupTest`, `Account`, `Illuminate\Http\RedirectResponse`, `AdminTest`?**
  _High betweenness centrality (0.133) - this node is a cross-community bridge._
- **Why does `_submit` connect `revisionProvider` to `accounts_screen.dart`, `web.php`?**
  _High betweenness centrality (0.040) - this node is a cross-community bridge._
- **Why does `Trade` connect `Trade` to `Illuminate\Http\JsonResponse`, `JournalTest`, `Illuminate\Database\Eloquent\Model`, `Transaction`, `TradeController.php`, `Illuminate\Support\Collection`, `bootstrap/app.php`, `TradeGroupTest`, `Account`, `Hashid`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **What connects `$schema`, `style`, `typescript` to the rest of the system?**
  _1173 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `stats.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.029850746268656716 - nodes in this community are weakly interconnected._
- **Should `GeminiKey` be split into smaller, more focused modules?**
  _Cohesion score 0.09462365591397849 - nodes in this community are weakly interconnected._