export type Direction = 'buy' | 'sell'
export type TradeStatus = 'open' | 'win' | 'loss' | 'be'
/** Posisi stop loss terhadap entry; null bila SL tidak diisi. */
export type StopState = 'risk' | 'breakeven' | 'locked' | null

export interface AccountBrief {
  id: number
  name: string
  broker: string | null
  currency: string
}

export interface CurrentAccount extends AccountBrief {
  initial_balance: string | number
  started_at: string
}

/** Satu lapis entry: harga dan lotnya sendiri. */
export interface TradeLayer {
  price: number | null
  lot: number | null
}

export interface Trade {
  id: number
  symbol: string
  direction: Direction
  status: TradeStatus
  setup: string | null
  notes?: string | null
  source?: 'manual' | 'ai'
  lot: number | null
  /** Kosong = trade satu layer; `entry_price` dan `lot` adalah ringkasannya. */
  entries?: TradeLayer[]
  entry_price: number | null
  sl_price: number | null
  stop_state?: StopState
  tp_price: number | null
  exit_price: number | null
  pnl: number | null
  rr_planned: number | null
  rr_realized: number | null
  opened_at: string
  closed_at?: string | null
  tags: string[]
}

/**
 * Paginator Laravel apa adanya — hanya field yang benar-benar dipakai layar.
 *
 * `links` sengaja tidak dipakai untuk tombol maju/mundur: label pertama dan
 * terakhirnya diterjemahkan Laravel, dan tanpa berkas lang/id keduanya keluar
 * mentah sebagai "pagination.previous". Panahnya digambar dari *_page_url.
 */
export interface Paginated<T> {
  data: T[]
  links: { url: string | null; label: string; active: boolean }[]
  current_page: number
  last_page: number
  prev_page_url: string | null
  next_page_url: string | null
  from: number | null
  to: number | null
  total: number
}

export interface EquityPoint {
  date: string
  balance: number
  pnl: number
  flow: number
}

export interface DayStat {
  pnl: number
  trades: number
  wins: number
  losses: number
}

export interface Breakdown {
  [key: string]: { trades: number; pnl: number; win_rate_pct: number }
}

export interface Summary {
  period: { from: string; to: string }
  currency: string
  initial_balance: number
  balance: number
  net_flow: number
  total_trades: number
  open_trades: number
  wins: number
  losses: number
  breakeven: number
  win_rate_pct: number
  net_pnl: number
  gross_profit: number
  gross_loss: number
  profit_factor: number | null
  expectancy: number
  avg_win: number
  avg_loss: number
  payoff_ratio: number | null
  largest_win: number
  largest_loss: number
  avg_rr_planned: number | null
  avg_rr_realized: number | null
  max_drawdown: { amount: number; pct: number }
  longest_win_streak: number
  longest_loss_streak: number
  by_symbol: Breakdown
  by_direction: Breakdown
  by_weekday: Breakdown
  by_hour: Breakdown
  by_setup: Breakdown
  violations: Record<string, string[]>
}

export interface RuleStatus {
  date: string
  pnl: number
  trades: number
  opening_balance: number
  loss_limit: number | null
  loss_used: number
  loss_breached: boolean
  profit_goal: number | null
  profit_reached: boolean
  max_trades: number | null
  trades_breached: boolean
  drawdown_pct: number
  max_drawdown_pct: number | null
  drawdown_breached: boolean
  has_rules: boolean
}

export interface PageProps {
  auth: { user: { id: number; name: string; email: string; is_admin: boolean } | null }
  accounts: AccountBrief[]
  currentAccount: CurrentAccount | null
  flash: { success: string | null; error: string | null; info: string | null }
  [key: string]: unknown
}
