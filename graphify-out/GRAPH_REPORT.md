# Graph Report - trade-history  (2026-09-25)

## Corpus Check
- 301 files · ~130,063 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2749 nodes · 4719 edges · 157 communities (139 shown, 18 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 55 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `babc2e79`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- stats.dart
- GeminiKey
- composer.json
- Illuminate\Database\Migrations\Migration
- utils.ts
- dropdown-menu/index.ts
- devDependencies
- select/index.ts
- compilerOptions
- scripts
- AppLayout.vue
- cn
- require-dev
- useFormat.ts
- common.dart
- EquityChart.vue
- Admin.vue
- TestCase
- AccountStats
- tasteskill: Anti-Slop Frontend Skill
- AnalysisChat.vue
- api.php
- components.json
- dependencies
- Illuminate\Http\Request
- Tabs.vue
- Alur import trade dari screenshot
- journal.dart
- DialogDescription.vue
- SetupPicker.vue
- DropdownMenuContent.vue
- Calendar.vue
- Accounts.vue
- Index.vue
- User
- Transactions.vue
- package.json
- App Icon 512 (rounded squircle, rising-chart mark)
- Tabel trades
- trade.dart
- Transaction
- trade_form_screen.dart
- transaction_form.dart
- shadcn-vue (reka-ui)
- JournalTest
- Appendix B - Canonical Sources (read these before reinventing)
- App\Services\AccountStats
- compose service: app (FrankenPHP dev)
- Penyimpanan bukti transfer privat
- Tabel accounts
- PWA (manifest + service worker tulis tangan)
- logging.php
- config
- trades_screen.dart
- User.php
- support.dart
- Account
- Illuminate\Http\RedirectResponse
- require
- make-icons.py
- rules_screen.dart
- models_test.dart
- format.dart
- account.dart
- psr-4
- Form.vue
- DialogContent.vue
- ../core/format.dart
- Inertia\Response
- session.dart
- artisan
- prefsProvider
- chat_screen.dart
- backdrop.dart
- theme.dart
- journal_api.dart
- 4. DESIGN ENGINEERING DIRECTIVES (Bias Correction)
- DemoSeeder.php
- Illuminate\Http\JsonResponse
- AnalysisTest
- RegisterRequest
- calendar_screen.dart
- transactions_screen.dart
- app.dart
- trade_widgets.dart
- api_client.dart
- Trade
- types/index.ts
- SelectContent.vue
- TradeImportTest
- report_screen.dart
- 10. REFERENCE VOCABULARY (Pattern Names the Agent Should Know)
- accounts_screen.dart
- trade_filters_sheet.dart
- analysis_screen.dart
- login_screen.dart
- .application
- profile_screen.dart
- package:flutter/material.dart
- journalProvider
- Illuminate\Database\Eloquent\Model
- charts.dart
- TradeDayTest
- ../core/theme.dart
- ApiTest
- _ThinkingState
- 9. AI TELLS (Forbidden Patterns)
- setup
- TradeGroupTest
- APPENDICES - Real Source-Backed Reference Material
- 11. REDESIGN PROTOCOL
- json.dart
- 3. DEFAULT ARCHITECTURE & CONVENTIONS
- Gemini
- 6. PERFORMANCE & ACCESSIBILITY GUARDRAILS
- images.dart
- 12. THE BLOCK LIBRARY (Contract - Implementations Land Here Iteratively)
- 5. CONTEXT-AWARE PROACTIVITY
- Trade History — mobile
- 8. DARK MODE PROTOCOL
- DialogScrollContent.vue
- Dialog.vue
- DropdownMenuRadioItem.vue
- DropdownMenuSubContent.vue
- Rules.vue
- 7. DIAL DEFINITIONS (Technical Reference)
- vite.config.ts
- DialogTitle.vue
- DropdownMenuLabel.vue
- Separator.vue
- keywords
- DropdownMenuItem.vue
- @inertiajs/vue3
- @tailwindcss/vite
- @types/node
- @vitejs/plugin-vue
- FlutterActivity
- Input.vue
- home_user_trade_history_mobile_ios_runner_generatedpluginregistrant_h
- LaunchImage.imageset/README.md
- TradeFilters
- Progress.vue
- post-autoload-dump
- _TradeFormState

## God Nodes (most connected - your core abstractions)
1. `User` - 103 edges
2. `Account` - 56 edges
3. `cn()` - 52 edges
4. `Trade` - 42 edges
5. `TestCase` - 38 edges
6. `AccountStats` - 31 edges
7. `ReportTest` - 30 edges
8. `JournalTest` - 29 edges
9. `GeminiKey` - 28 edges
10. `journalProvider` - 25 edges

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

## Communities (157 total, 18 thin omitted)

### Community 0 - "stats.dart"
Cohesion: 0.03
Nodes (66): avgLoss, avgRrPlanned, avgRrRealized, avgWin, balance, breached, _breakdown, BreakdownRow (+58 more)

### Community 1 - "GeminiKey"
Cohesion: 0.10
Nodes (6): GeminiKey, Illuminate\Http\Client\ConnectionException, Illuminate\Http\Client\RequestException, Illuminate\Support\Facades\Http, AdminTest, AnalysisChatTest

### Community 2 - "composer.json"
Cohesion: 0.14
Nodes (13): autoload-dev, psr-4, description, extra, laravel, dont-discover, license, minimum-stability (+5 more)

### Community 3 - "Illuminate\Database\Migrations\Migration"
Cohesion: 0.05
Nodes (4): Illuminate\Database\Migrations\Migration, Illuminate\Database\Schema\Blueprint, Illuminate\Support\Facades\DB, Illuminate\Support\Facades\Schema

### Community 4 - "utils.ts"
Cohesion: 0.12
Nodes (10): delegatedProps, props, props, props, props, props, props, props (+2 more)

### Community 5 - "dropdown-menu/index.ts"
Cohesion: 0.06
Nodes (22): emits, forwarded, props, delegatedProps, emits, forwarded, props, props (+14 more)

### Community 6 - "devDependencies"
Cohesion: 0.12
Nodes (17): concurrently, fontaine, laravel-vite-plugin, devDependencies, concurrently, fontaine, laravel-vite-plugin, tailwindcss (+9 more)

### Community 7 - "select/index.ts"
Cohesion: 0.06
Nodes (21): emits, forwarded, props, props, delegatedProps, forwardedProps, props, props (+13 more)

### Community 8 - "compilerOptions"
Cohesion: 0.07
Nodes (26): DOM, DOM.Iterable, ESNext, node, resources/js/**/*.d.ts, resources/js/**/*.ts, resources/js/**/*.vue, vite/client (+18 more)

### Community 9 - "scripts"
Cohesion: 0.13
Nodes (15): scripts, dev, post-create-project-cmd, post-update-cmd, pre-package-uninstall, test, Composer\\Config::disableProcessTimeout, Illuminate\\Foundation\\ComposerScripts::prePackageUninstall (+7 more)

### Community 10 - "AppLayout.vue"
Cohesion: 0.07
Nodes (27): resources_css_app, BARE_PAGES, resources_js_components_ui_dropdown_menu_index_dropdownmenu, resources_js_components_ui_dropdown_menu_index_dropdownmenucontent, resources_js_components_ui_dropdown_menu_index_dropdownmenuitem, resources_js_components_ui_dropdown_menu_index_dropdownmenulabel, resources_js_components_ui_dropdown_menu_index_dropdownmenuseparator, resources_js_components_ui_dropdown_menu_index_dropdownmenutrigger (+19 more)

### Community 11 - "cn"
Cohesion: 0.13
Nodes (12): props, props, props, props, props, delegatedProps, props, props (+4 more)

### Community 12 - "require-dev"
Cohesion: 0.25
Nodes (8): require-dev, fakerphp/faker, laravel/pail, laravel/pao, laravel/pint, mockery/mockery, nunomaduro/collision, phpunit/phpunit

### Community 13 - "useFormat.ts"
Cohesion: 0.07
Nodes (38): axis, bars, changePct, niceStep(), props, totals, breached, lossPct (+30 more)

### Community 14 - "common.dart"
Cohesion: 0.03
Nodes (71): AsyncValue, Color get, EdgeInsetsGeometry, IconData?, _Cell, _DaySheet, _Grid, _DayHeader (+63 more)

### Community 15 - "EquityChart.vue"
Cohesion: 0.12
Nodes (15): active, areaPath, box, flowPoints, gridLines, hover, PAD, path (+7 more)

### Community 16 - "Admin.vue"
Cohesion: 0.09
Nodes (17): backingUp, Backup, csrf(), editing, gemini, GeminiKey, now, open (+9 more)

### Community 17 - "TestCase"
Cohesion: 0.07
Nodes (13): Illuminate\Foundation\Testing\RefreshDatabase, Illuminate\Foundation\Testing\TestCase, Illuminate\Http\UploadedFile, Illuminate\Support\Facades\File, Illuminate\Support\Facades\Storage, BackupTest, ErrorPageTest, FlashTest (+5 more)

### Community 18 - "AccountStats"
Cohesion: 0.09
Nodes (12): BackupDatabase, AccountStats, CarbonImmutable, Carbon\CarbonInterface, Illuminate\Console\Command, Illuminate\Foundation\Inspiring, Illuminate\Support\Carbon, Illuminate\Support\Collection (+4 more)

### Community 19 - "tasteskill: Anti-Slop Frontend Skill"
Cohesion: 0.13
Nodes (15): 0.A Read these signals first, 0.B Output a one-line "Design Read" before generating, 0. BRIEF INFERENCE (Read the Room Before Anything Else), 0.C If the brief is ambiguous, ask one question, do not guess, 0.D Anti-Default Discipline, 13. OUT OF SCOPE, 14. FINAL PRE-FLIGHT CHECK, 1.A Dial Inference (design read → dial values) (+7 more)

### Community 20 - "AnalysisChat.vue"
Cohesion: 0.12
Nodes (20): busy, clear(), close(), closing, confirming, csrf(), draft, error (+12 more)

### Community 21 - "api.php"
Cohesion: 0.18
Nodes (5): ReportController, Dompdf\Dompdf, Illuminate\Database\Eloquent\Collection, Illuminate\Http\Response, Route /

### Community 22 - "components.json"
Cohesion: 0.12
Nodes (16): aliases, components, composables, lib, ui, utils, iconLibrary, $schema (+8 more)

### Community 23 - "dependencies"
Cohesion: 0.11
Nodes (19): class-variance-authority, clsx, @lucide/vue, marked, dependencies, class-variance-authority, clsx, @lucide/vue (+11 more)

### Community 24 - "Illuminate\Http\Request"
Cohesion: 0.12
Nodes (16): AnalysisController, EnsureAdmin, EnsureTrader, HandleInertiaRequests, RequireAccount, SetCurrentAccount, UseRouteAccount, Closure (+8 more)

### Community 25 - "Tabs.vue"
Cohesion: 0.12
Nodes (11): delegatedProps, emits, forwarded, props, delegatedProps, props, delegatedProps, props (+3 more)

### Community 26 - "Alur import trade dari screenshot"
Cohesion: 0.15
Nodes (15): Alur kerja graphify untuk repo ini, robots.txt mengizinkan seluruh crawler, Alur import trade dari screenshot, AiImportDialog, Urutan pengerjaan 7 fase, Gemini::extractTrade(), Gemini API (gemini-3.5-flash), App\Services\Gemini (+7 more)

### Community 27 - "journal.dart"
Cohesion: 0.03
Nodes (59): accounts, aiEnabled, allowedSessions, amount, analysis, AnalysisPage, analyzedAt, balance (+51 more)

### Community 28 - "DialogDescription.vue"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 29 - "SetupPicker.vue"
Cohesion: 0.40
Nodes (5): emit, options, props, selected, SETUPS

### Community 30 - "DropdownMenuContent.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 31 - "Calendar.vue"
Cohesion: 0.07
Nodes (27): emit, iso(), maxAbs, props, today, WEEKDAYS, weeks, BadgeVariants (+19 more)

### Community 32 - "Accounts.vue"
Cohesion: 0.06
Nodes (38): busy, close(), csrf(), emit, error, file, onDrop(), onPaste() (+30 more)

### Community 33 - "Index.vue"
Cohesion: 0.07
Nodes (28): frameClass(), frameGap(), frameTop(), Groupable, activeFilters, apply, blockRange(), currency (+20 more)

### Community 34 - "User"
Cohesion: 0.18
Nodes (4): User, AnnualReport, Illuminate\Foundation\Auth\User, ReportTest

### Community 35 - "Transactions.vue"
Cohesion: 0.06
Nodes (29): resources_js_components_ui_select_index_select, resources_js_components_ui_select_index_selectcontent, resources_js_components_ui_select_index_selectitem, resources_js_components_ui_select_index_selecttrigger, resources_js_components_ui_select_index_selectvalue, monthLabel(), toIdr(), errors (+21 more)

### Community 36 - "package.json"
Cohesion: 0.20
Nodes (9): @laravel/multiplex, optionalDependencies, @laravel/multiplex, private, $schema, scripts, build, dev (+1 more)

### Community 37 - "App Icon 512 (rounded squircle, rising-chart mark)"
Cohesion: 0.42
Nodes (10): Apple Touch Icon 180 (iOS home screen), App Icon 192 (PWA install/home-screen size), Favicon 32 (browser tab size), Small-Size Legibility Simplification, App Icon 512 (rounded squircle, rising-chart mark), Rising Trend Line Brand Mark, Rounded Squircle Container Treatment, Maskable Icon 192 (full-bleed, adaptive-mask safe) (+2 more)

### Community 38 - "Tabel trades"
Cohesion: 0.20
Nodes (10): Kolom ai_raw (jejak bacaan Gemini), Font self-host via bunny() laravel-vite-plugin, Mata uang akun USD / USC / IDR, Inertia v3 + Vue 3 (script setup, TS), Laravel 13 monolith, price() di useFormat.ts, Kolom RR menampilkan R hasil dan R rencana, Screenshot trade tidak disimpan (+2 more)

### Community 39 - "trade.dart"
Cohesion: 0.04
Nodes (45): DateTime get, int get, active, aiRaw, closedAt, daily, data, day (+37 more)

### Community 40 - "Transaction"
Cohesion: 0.13
Nodes (8): ProfileController, TransactionController, Transaction, Uploads, Illuminate\Support\Facades\URL, Illuminate\Validation\Rule, Laravel\Sanctum\PersonalAccessToken, Symfony\Component\HttpFoundation\StreamedResponse

### Community 41 - "trade_form_screen.dart"
Cohesion: 0.05
Nodes (42): ai_import_sheet.dart, double get, account, aiEnabled, _aiFields, _aiPreview, _aiRaw, _badge (+34 more)

### Community 42 - "transaction_form.dart"
Cohesion: 0.05
Nodes (41): AccountBrief, dart:typed_data, account, AiImport, _AiImportSheet, _AiImportSheetState, build, _busy (+33 more)

### Community 43 - "shadcn-vue (reka-ui)"
Cohesion: 0.32
Nodes (8): Tema dark-only, Token warna nfp dark di-flatten ke :root, Utilities .glass / ornamen / hover-lift, PnlCalendar (grid CSS 7 kolom manual), Aturan warna semantik (gold / success / destructive / cyan), shadcn-vue (reka-ui), Tailwind CSS v4 (CSS-first), Waktu disimpan dalam Asia/Jakarta

### Community 45 - "Appendix B - Canonical Sources (read these before reinventing)"
Cohesion: 0.13
Nodes (15): Appendix B - Canonical Sources (read these before reinventing), Apple Liquid Glass (Apple platforms only), Atlassian, Bootstrap, Carbon, Fluent UI, GOV.UK, Material Web (+7 more)

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
Nodes (39): append, _block, createState, currency, daily, day, dispose, _filters (+31 more)

### Community 54 - "User.php"
Cohesion: 0.09
Nodes (11): UserFactory, Illuminate\Database\Eloquent\Attributes\Hidden, Illuminate\Database\Eloquent\Factories\Factory, Illuminate\Database\Eloquent\Factories\HasFactory, Illuminate\Notifications\Notifiable, Illuminate\Support\Facades\Hash, Illuminate\Support\Str, Laravel\Sanctum\HasApiTokens (+3 more)

### Community 55 - "support.dart"
Cohesion: 0.07
Nodes (27): dart:io, HttpClientAdapter, body, close, defaultRoutes, FakeServer, fetch, fixture (+19 more)

### Community 56 - "Account"
Cohesion: 0.13
Nodes (3): Account, Illuminate\Database\Eloquent\Relations\HasMany, RuleLimitTest

### Community 57 - "Illuminate\Http\RedirectResponse"
Cohesion: 0.15
Nodes (4): AccountController, AdminController, Illuminate\Http\RedirectResponse, Symfony\Component\HttpFoundation\BinaryFileResponse

### Community 58 - "require"
Cohesion: 0.20
Nodes (9): require, dompdf/dompdf, hashids/hashids, inertiajs/inertia-laravel, laravel/framework, laravel/octane, laravel/sanctum, laravel/tinker (+1 more)

### Community 59 - "make-icons.py"
Cohesion: 0.50
Nodes (4): Image, pil, draw_icon(), main()

### Community 60 - "rules_screen.dart"
Cohesion: 0.06
Nodes (34): account, _allowed, build, _busy, _controllers, createState, _currency, dispose (+26 more)

### Community 61 - "models_test.dart"
Cohesion: 0.13
Nodes (14): dart:convert, Exception, ApiException, main, main, main, package:flutter_test/flutter_test.dart, package:trade_history/core/api_client.dart (+6 more)

### Community 62 - "format.dart"
Cohesion: 0.06
Nodes (33): amount, clock, compact, currencies, currency, dateTime, _digits, _fixed (+25 more)

### Community 63 - "account.dart"
Cohesion: 0.09
Nodes (22): ../core/json.dart, AccountBrief, accountNumber, accounts, AccountTotal, avatar, balance, broker (+14 more)

### Community 64 - "psr-4"
Cohesion: 0.40
Nodes (5): autoload, psr-4, App\\, Database\\Factories\\, Database\\Seeders\\

### Community 65 - "Form.vue"
Cohesion: 0.08
Nodes (24): FEATURES, model, shown, Props, ButtonVariants, resources_js_components_ui_input_index_input, resources_js_components_ui_label_index_label, delegatedProps (+16 more)

### Community 67 - "DialogContent.vue"
Cohesion: 0.25
Nodes (6): delegatedProps, emits, forwarded, props, delegatedProps, props

### Community 68 - "../core/format.dart"
Cohesion: 0.14
Nodes (13): Color, ../core/format.dart, build, color, currency, fraction, label, _Meter (+5 more)

### Community 69 - "Inertia\Response"
Cohesion: 0.12
Nodes (10): LoginController, RegisterController, Controller, RuleController, Illuminate\Auth\Events\Lockout, Illuminate\Support\Facades\Auth, Illuminate\Support\Facades\RateLimiter, Illuminate\Validation\ValidationException (+2 more)

### Community 70 - "session.dart"
Cohesion: 0.09
Nodes (29): FlutterSecureStorage, journal_api.dart, JournalApi, _accountKey, apiClientProvider, build, bump, defaultServer (+21 more)

### Community 79 - "prefsProvider"
Cohesion: 0.29
Nodes (8): int?, prefsProvider, Revision, select, SelectedAccount, ServerController, _load, Notifier

### Community 80 - "chat_screen.dart"
Cohesion: 0.07
Nodes (27): analysis_screen.dart, dart:async, _account, _bubble, _busy, _charsPerSecond, ChatScreen, _ChatScreenState (+19 more)

### Community 81 - "backdrop.dart"
Cohesion: 0.14
Nodes (13): CustomPainter, dart:ui, Backdrop, build, child, _glow, _grid, _Ornaments (+5 more)

### Community 82 - "theme.dart"
Cohesion: 0.06
Nodes (30): accent, accentForeground, AppColors, background, base, border, buildTheme, card (+22 more)

### Community 83 - "journal_api.dart"
Cohesion: 0.06
Nodes (34): accounts, analysis, avatarUrl, calendar, chat, client, dashboard, deleteAccount (+26 more)

### Community 84 - "4. DESIGN ENGINEERING DIRECTIVES (Bias Correction)"
Cohesion: 0.17
Nodes (12): 4.10 Quotes & Testimonials, 4.11 Page Theme Lock (Light / Dark Mode Consistency), 4.1 Typography, 4.2 Color Calibration, 4.3 Layout Diversification, 4.4 Materiality, Shadows, Cards, 4.5 Interactive UI States, 4.6 Data & Form Patterns (+4 more)

### Community 85 - "DemoSeeder.php"
Cohesion: 0.38
Nodes (3): DatabaseSeeder, DemoSeeder, Illuminate\Database\Seeder

### Community 86 - "Illuminate\Http\JsonResponse"
Cohesion: 0.16
Nodes (3): AuthController, TradeController, Illuminate\Http\JsonResponse

### Community 88 - "RegisterRequest"
Cohesion: 0.15
Nodes (5): RegisterRequest, TradeRequest, Illuminate\Contracts\Validation\Validator, Illuminate\Foundation\Http\FormRequest, Illuminate\Validation\Rules\Password

### Community 89 - "calendar_screen.dart"
Cohesion: 0.05
Nodes (44): charts.dart, DayStat?, account, build, calendarProvider, CalendarScreen, _CalendarScreenState, _content (+36 more)

### Community 91 - "transactions_screen.dart"
Cohesion: 0.08
Nodes (27): AsyncNotifier, account, api, _content, createState, first, FundsController, FundsList (+19 more)

### Community 92 - "app.dart"
Cohesion: 0.07
Nodes (28): features/accounts/accounts_screen.dart, features/analysis/analysis_screen.dart, features/analysis/chat_screen.dart, features/auth/login_screen.dart, features/auth/register_screen.dart, features/calendar/calendar_screen.dart, features/dashboard/dashboard_screen.dart, features/more/more_screen.dart (+20 more)

### Community 93 - "trade_widgets.dart"
Cohesion: 0.07
Nodes (26): build, currency, dimmed, direction, first, group, groupFrame, groupGap (+18 more)

### Community 94 - "api_client.dart"
Cohesion: 0.08
Nodes (25): Dio, json.dart, ApiClient, _body, bytes, _clean, delete, dio (+17 more)

### Community 95 - "Trade"
Cohesion: 0.13
Nodes (8): CalendarController, CarbonImmutable, getRouteKey(), Trade, AppServiceProvider, Hashid, Hashids\Hashids, Illuminate\Support\ServiceProvider

### Community 96 - "types/index.ts"
Cohesion: 0.09
Nodes (18): pages, props, props, TAG, message, MESSAGES, props, signedIn (+10 more)

### Community 97 - "SelectContent.vue"
Cohesion: 0.29
Nodes (6): resources_js_components_ui_select_index_selectscrolldownbutton, resources_js_components_ui_select_index_selectscrollupbutton, delegatedProps, emits, forwarded, props

### Community 99 - "report_screen.dart"
Cohesion: 0.09
Nodes (24): DateTime, _address, build, _busy, createState, dispose, _endOfYear, _errors (+16 more)

### Community 100 - "10. REFERENCE VOCABULARY (Pattern Names the Agent Should Know)"
Cohesion: 0.20
Nodes (10): 10. REFERENCE VOCABULARY (Pattern Names the Agent Should Know), Animation Library Choice, Cards & Containers, Galleries & Media, Hero Paradigms, Layout & Grids, Micro-Interactions & Effects, Navigation & Menus (+2 more)

### Community 102 - "accounts_screen.dart"
Cohesion: 0.06
Nodes (40): common.dart, ConsumerWidget, currentAccountProvider, accountsProvider, AccountsScreen, _archived, _balance, _broker (+32 more)

### Community 103 - "trade_filters_sheet.dart"
Cohesion: 0.10
Nodes (19): build, _choices, _copy, createState, _dateButton, dispose, initial, _pickDate (+11 more)

### Community 104 - "analysis_screen.dart"
Cohesion: 0.11
Nodes (19): ../dashboard/dashboard_screen.dart, _aiCard, analysisProvider, AnalysisScreen, _AnalysisScreenState, _Breakdown, build, _content (+11 more)

### Community 105 - "login_screen.dart"
Cohesion: 0.12
Nodes (18): List, AuthShell, build, _busy, _canRegisterProvider, children, createState, dispose (+10 more)

### Community 106 - ".application"
Cohesion: 0.11
Nodes (14): Any, Bool, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate (+6 more)

### Community 107 - "profile_screen.dart"
Cohesion: 0.06
Nodes (33): ../core/api_client.dart, ../core/images.dart, ../data/journal_api.dart, Map, meProvider, sessionProvider, build, MoreScreen (+25 more)

### Community 108 - "package:flutter/material.dart"
Cohesion: 0.04
Nodes (52): app.dart, bool get, ../data/session.dart, FilledButton, login_screen.dart, build, _busy, _confirmation (+44 more)

### Community 109 - "journalProvider"
Cohesion: 0.10
Nodes (32): ConsumerState, ConsumerStatefulWidget, journalProvider, revisionProvider, selectedAccountProvider, _AccountForm, _AccountFormState, _after (+24 more)

### Community 110 - "Illuminate\Database\Eloquent\Model"
Cohesion: 0.16
Nodes (6): AccountRule, AiAnalysis, Illuminate\Database\Eloquent\Attributes\Fillable, Illuminate\Database\Eloquent\Model, Illuminate\Database\Eloquent\Relations\BelongsTo, Illuminate\Database\Eloquent\Relations\HasOne

### Community 111 - "charts.dart"
Cohesion: 0.11
Nodes (17): dart:math, double?, base, build, currency, data, EquityChart, height (+9 more)

### Community 113 - "../core/theme.dart"
Cohesion: 0.12
Nodes (14): ../core/theme.dart, build, MarkdownView, selectable, source, build, enabled, kSetups (+6 more)

### Community 115 - "_ThinkingState"
Cohesion: 0.31
Nodes (9): _Thinking, _ThinkingState, _FilterSheet, _FilterSheetState, Shimmer, _ShimmerState, SingleTickerProviderStateMixin, State (+1 more)

### Community 116 - "9. AI TELLS (Forbidden Patterns)"
Cohesion: 0.25
Nodes (8): 9.A Visual & CSS, 9. AI TELLS (Forbidden Patterns), 9.B Typography, 9.C Layout & Spacing, 9.D Content & Data ("Jane Doe" Effect), 9.E External Resources & Components, 9.F Production-Test Tells (banned outright), 9.G EM-DASH BAN (the single most-violated Tell)

### Community 117 - "setup"
Cohesion: 0.25
Nodes (8): post-root-package-install, setup, composer install, npm install --ignore-scripts, npm run build, @php artisan key:generate, @php artisan migrate --force, @php -r \"file_exists('.env') || copy('.env.example', '.env');\

### Community 119 - "APPENDICES - Real Source-Backed Reference Material"
Cohesion: 0.29
Nodes (6): APPENDICES - Real Source-Backed Reference Material, Appendix A - Install Commands per Design System, Appendix C - Apple Liquid Glass: Honest Web Approximation, Safer web approximation skeleton, What is NOT official, What is official

### Community 120 - "11. REDESIGN PROTOCOL"
Cohesion: 0.29
Nodes (7): 11.A Detect the Mode (first action), 11.B Audit Before Touching, 11.C Preservation Rules, 11.D Modernisation Levers (priority order), 11.E Decision Tree: Targeted Evolution vs Full Redesign, 11.F What Never Changes Silently, 11. REDESIGN PROTOCOL

### Community 121 - "json.dart"
Cohesion: 0.18
Nodes (10): Json, list, map, strings, toDouble, toDoubleOrNull, toInt, toIntOrNull (+2 more)

### Community 122 - "3. DEFAULT ARCHITECTURE & CONVENTIONS"
Cohesion: 0.29
Nodes (7): 3.A Stack, 3.B State, 3.C Icons, 3.D Emoji Policy, 3. DEFAULT ARCHITECTURE & CONVENTIONS, 3.E Responsiveness & Layout Mechanics, 3.F Dependency Verification (mandatory)

### Community 123 - "Gemini"
Cohesion: 0.14
Nodes (8): DashboardController, TradeImportController, Gemini, Period, Carbon\CarbonImmutable, Illuminate\Support\Facades\Log, RuntimeException, Throwable

### Community 124 - "6. PERFORMANCE & ACCESSIBILITY GUARDRAILS"
Cohesion: 0.29
Nodes (7): 6.A Hardware Acceleration, 6.B Reduced Motion (mandatory), 6.C Dark Mode (mandatory for any consumer-facing page), 6.D Core Web Vitals Targets, 6.E DOM Cost, 6.F Z-Index Restraint, 6. PERFORMANCE & ACCESSIBILITY GUARDRAILS

### Community 125 - "images.dart"
Cohesion: 0.29
Nodes (6): compressImage, original, quality, side, package:flutter/foundation.dart, package:flutter_image_compress/flutter_image_compress.dart

### Community 126 - "12. THE BLOCK LIBRARY (Contract - Implementations Land Here Iteratively)"
Cohesion: 0.40
Nodes (5): 12.A File Location, 12.B Required Frontmatter, 12.C Required Body Sections, 12.D Block-Library Discipline, 12. THE BLOCK LIBRARY (Contract - Implementations Land Here Iteratively)

### Community 127 - "5. CONTEXT-AWARE PROACTIVITY"
Cohesion: 0.40
Nodes (5): 5.A Sticky-Stack - Canonical Skeleton, 5.B Horizontal-Pan - Canonical Skeleton, 5.C Scroll-Reveal Stagger - Canonical Skeleton (lighter alternative), 5. CONTEXT-AWARE PROACTIVITY, 5.D Forbidden Animation Patterns

### Community 129 - "Trade History — mobile"
Cohesion: 0.33
Nodes (5): Catatan, Menjalankan, Paket, Peta kode, Trade History — mobile

### Community 130 - "8. DARK MODE PROTOCOL"
Cohesion: 0.40
Nodes (5): 8.A Token Strategy (pick one, stick to it), 8.B Do Not Prescribe Specific Colors Here, 8.C Default Mode, 8.D Test in Both Modes Before Finishing, 8. DARK MODE PROTOCOL

### Community 131 - "DialogScrollContent.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 132 - "Dialog.vue"
Cohesion: 0.50
Nodes (3): emits, forwarded, props

### Community 133 - "DropdownMenuRadioItem.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 134 - "DropdownMenuSubContent.vue"
Cohesion: 0.40
Nodes (4): delegatedProps, emits, forwarded, props

### Community 135 - "Rules.vue"
Cohesion: 0.09
Nodes (18): html, props, resources_js_components_ui_textarea_index_textarea, emits, modelValue, props, AmountKey, currency (+10 more)

### Community 136 - "7. DIAL DEFINITIONS (Technical Reference)"
Cohesion: 0.50
Nodes (4): 7. DIAL DEFINITIONS (Technical Reference), DESIGN_VARIANCE (Level 1-10), MOTION_INTENSITY (Level 1-10), VISUAL_DENSITY (Level 1-10)

### Community 137 - "vite.config.ts"
Cohesion: 0.50
Nodes (3): ref_node_fs, ref_node_path, ref_vue_compiler_sfc

### Community 138 - "DialogTitle.vue"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 139 - "DropdownMenuLabel.vue"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 141 - "keywords"
Cohesion: 0.67
Nodes (3): keywords, framework, laravel

### Community 142 - "DropdownMenuItem.vue"
Cohesion: 0.50
Nodes (3): delegatedProps, forwardedProps, props

### Community 149 - "Input.vue"
Cohesion: 0.50
Nodes (3): emits, modelValue, props

### Community 156 - "post-autoload-dump"
Cohesion: 0.67
Nodes (3): post-autoload-dump, Illuminate\\Foundation\\ComposerScripts::postAutoloadDump, @php artisan package:discover --ansi

## Ambiguous Edges - Review These
- `robots.txt mengizinkan seluruh crawler` → `REGISTER_TOKEN penjaga pendaftaran mandiri`  [AMBIGUOUS]
  public/robots.txt · relation: conceptually_related_to

## Knowledge Gaps
- **1304 isolated node(s):** `$schema`, `style`, `typescript`, `config`, `css` (+1299 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **18 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `robots.txt mengizinkan seluruh crawler` and `REGISTER_TOKEN penjaga pendaftaran mandiri`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `User` connect `User` to `GeminiKey`, `TradeImportTest`, `Inertia\Response`, `JournalTest`, `Illuminate\Database\Eloquent\Model`, `TradeDayTest`, `TestCase`, `ApiTest`, `DemoSeeder.php`, `Illuminate\Http\JsonResponse`, `User.php`, `RegisterRequest`, `Illuminate\Http\RedirectResponse`, `Account`, `AnalysisTest`, `TradeGroupTest`?**
  _High betweenness centrality (0.115) - this node is a cross-community bridge._
- **Why does `_submit` connect `journalProvider` to `api.php`, `accounts_screen.dart`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **Why does `Uploads` connect `Transaction` to `Account`, `TestCase`, `User.php`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **What connects `$schema`, `style`, `typescript` to the rest of the system?**
  _1304 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `stats.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.029850746268656716 - nodes in this community are weakly interconnected._
- **Should `GeminiKey` be split into smaller, more focused modules?**
  _Cohesion score 0.09659090909090909 - nodes in this community are weakly interconnected._