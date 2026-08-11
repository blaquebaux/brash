#!/usr/bin/env julia
# ============================================================================
# brash_crypto_live.jl — BRASH on the REAL crypto rail — aggressive (fractional-Kelly) sizing.
#
# The validated crypto-trend edge (research/brash_crypto_validation.py: OOS +0.72 Sharpe /
# -12% maxDD on real BTC/ETH vs buy&hold -76%) — traded on the ACTUAL rail, not the ETF proxy, now
# that crypto execution is wired into the engine. data(v1beta3 BTC/USD + ETH/USD) -> multi-horizon
# trend x vol-target (long-only) -> [ SAFETY GATE ] -> governed FRACTIONAL orders (crypto venue).
#
# Uses the engine's crypto pieces (CryptoPanel + AlpacaVenue crypto-mode + execute_rebalance_frac!),
# so orders are FRACTIONAL (e.g. 0.05 BTC), time_in_force=gtc, "BTC/USD" symbols — through the SAME
# Layer-3 safety gate + reconcile as the spine. Isolated ledger/hwm (pool "crypto").
#
# MODES: dry-run by default via the wrapper (BB_DRYRUN=1 -> compute + log the fractional book, NO
# venue). Paper: unset BB_DRYRUN with a crypto-enabled paper account. Real money requires
# BB_LIVE_CONFIRM=I_UNDERSTAND_THIS_IS_REAL_MONEY. Kill switch: ~/.config/blaquebaux/HALT.
# Crypto trades 24/7 (annualize 365). Run:  julia --project=engine live/brash_crypto_live.jl
# NOT validated to the spine's bar; a paper-path graduation of the research.
# ============================================================================
using Dates, Printf, Statistics

const REPO   = normpath(joinpath(@__DIR__, ".."))
const ENGINE = joinpath(REPO, "engine")
include(joinpath(ENGINE, "src/module_7_execution/module_7_execution.jl"))
include(joinpath(ENGINE, "src/module_10_feedback/module_10_feedback.jl"))
include(joinpath(ENGINE, "src/module_13_portfolio/module_13_portfolio.jl"))
include(joinpath(ENGINE, "src/module_1_data/crypto_panel.jl"))
include(joinpath(ENGINE, "src/module_8_governance/safety_gate.jl"))
using .ExecutionLayer, .FeedbackLayer, .PortfolioOptModule, .CryptoPanel, .SafetyGate
include(joinpath(ENGINE, "scripts/live_execution.jl"))

const ASSETS = ["BTC/USD", "ETH/USD"]
const LIVE_SENTINEL = "I_UNDERSTAND_THIS_IS_REAL_MONEY"
const VOL_TARGET = 0.25
const CAP_GROSS = 1.5

_readf(p) = isfile(p) ? (v = tryparse(Float64, strip(read(p, String))); v === nothing ? NaN : v) : NaN
_writef(p, x) = (mkpath(dirname(p)); write(p, string(x)))
function ewma_vol_ann(r; hl = 20, ann = 365)
    isempty(r) && return NaN; lam = 0.5^(1/hl); v = float(r[1])^2
    for t in eachindex(r); v = t == 1 ? float(r[t])^2 : lam*v + (1-lam)*float(r[t])^2; end
    sqrt(max(v, 1e-12)) * sqrt(ann)
end

function crypto_target(panel, cap)
    R = panel.returns; T = size(R, 1)
    net = Dict{String,Float64}(); price = Dict{String,Float64}()
    for (i, a) in enumerate(ASSETS)
        r = R[:, i]; frac = mean([(prod(1 .+ r[T-h+1:T]) - 1) > 0 ? 1.0 : 0.0 for h in (30, 60, 120)])
        net[a] = frac * (VOL_TARGET / max(ewma_vol_ann(r), 1e-6)) / length(ASSETS); price[a] = panel.prices[i]
    end
    g = sum(abs, values(net)); g > CAP_GROSS && for a in keys(net); net[a] *= CAP_GROSS / g; end
    (targets = Dict(a => net[a] * cap / price[a] for a in ASSETS), prices = price, net = net, gross = sum(abs, values(net)))
end

function main(; capital = nothing, pool = "crypto", limits::SafetyLimits = SafetyLimits(),
              db_path     = get(ENV, "BB_LEDGER_PATH", joinpath(REPO, "alpaca_ledger_brash_crypto.sqlite")),
              audit_path  = get(ENV, "BB_AUDIT_PATH",  joinpath(REPO, "alpaca_audit_brash_crypto.jsonl")),
              hwm_path    = get(ENV, "BB_HWM_PATH",    joinpath(homedir(), ".config", "blaquebaux", "equity_hwm_brash_crypto.txt")),
              equity_path = get(ENV, "BB_EQUITY_PATH", joinpath(homedir(), ".config", "blaquebaux", "equity_last_brash_crypto.txt")))
    (get(ENV, "ALPACA_KEY_ID", "") == "" || get(ENV, "ALPACA_SECRET_KEY", "") == "") &&
        error("Set ALPACA_KEY_ID and ALPACA_SECRET_KEY (read-only bars are needed even in dry-run).")
    dryrun = get(ENV, "BB_DRYRUN", "") in ("1", "true", "yes")
    panel = crypto_panel_at(CryptoPanelProvider(ASSETS; lookback = 220))
    fresh = (Dates.today() - panel.asof) <= Day(3)
    bk = crypto_target(panel, capital === nothing ? 100_000.0 : capital)

    if dryrun
        @info "BRASH-CRYPTO dry run" asof=panel.asof gross=round(bk.gross, digits=2)
        println("\n  crypto-trend book (real BTC/ETH, fractional):")
        for a in ASSETS
            @printf("    %-8s %+6.1f%%  ->  %.6f units @ \$%.0f\n", a, 100*get(bk.net, a, 0.0), get(bk.targets, a, 0.0), get(bk.prices, a, NaN))
        end
        ok, reasons = preflight(; account_status = "ACTIVE", equity = 100_000.0, hwm = 100_000.0, last_equity = 100_000.0,
            buying_power = 100_000.0, data_fresh = fresh, targets = bk.targets, prices = bk.prices, limits = limits)
        println("\n  DRY RUN — no venue, no orders. Gate: ", ok ? "PASS" : "ABORT: " * join(reasons, "; ")); return ok ? :dryrun_ok : :dryrun_gate_abort
    end

    live = get(ENV, "BB_LIVE_CONFIRM", "") == LIVE_SENTINEL; paper = !live; mode = live ? "*** LIVE REAL MONEY ***" : "paper"
    @info "brash_crypto_live starting" mode; live && alert("BRASH-CRYPTO LIVE REAL-MONEY mode engaged"; level = :critical)
    venue = AlpacaVenue(; paper = paper, crypto = true)                  # fractional qty + gtc + BTC/USD symbols
    built = build_live_controller(; venue = venue, ledger_config = LedgerConfig(; db_path = db_path), audit_path = audit_path)
    ctrl, ledger = built.ctrl, built.ledger
    try
        connect!(venue) || (alert("ABORT [$mode]: connect failed (bitdollar-crypto)"; level = :critical); return :connect_failed)
        acct = account_info(venue); acct === nothing && (alert("ABORT [$mode]: no account (bitdollar-crypto)"; level = :critical); return :no_account)
        cap = capital === nothing ? acct.equity : capital; hwm = max(load_hwm(hwm_path), acct.equity); last_eq = _readf(equity_path)
        bk = crypto_target(panel, cap)
        ok, reasons = preflight(; account_status = acct.status, trading_blocked = acct.trading_blocked, account_blocked = acct.account_blocked,
            equity = acct.equity, hwm = hwm, last_equity = last_eq, buying_power = acct.buying_power, data_fresh = fresh, targets = bk.targets, prices = bk.prices, limits = limits)
        save_hwm(hwm, hwm_path); _writef(equity_path, acct.equity)
        !ok && (msg = "SAFETY ABORT [$mode] (bitdollar-crypto): " * join(reasons, "; "); @error msg; halt!(ctrl, "safety gate"); alert(msg; level = :critical); return :aborted)
        reset_daily!(ctrl); set_pool_budget!(ctrl, pool, limits.max_gross_leverage * acct.equity); set_pool_loss_limit!(ctrl, pool, limits.max_daily_loss)
        set_pool_staleness!(ctrl, pool, Day(3)); feed_staleness!(ctrl, pool; stale = !fresh); isfinite(last_eq) && update_pnl!(ctrl, pool, acct.equity - last_eq)
        ncanc = cancel_all_open!(venue); ncanc > 0 && sleep(2)
        for (sym, qty) in positions(venue, ctrl.account); apply_fill!(ctrl, sym, qty); end
        res = execute_rebalance_frac!(ctrl, ledger; targets = bk.targets, prices = bk.prices, signal_id = "brash_crypto",
            regime = "crypto-trend", solve_id = Dates.format(panel.asof, "yyyymmdd"), pool_id = pool, settle_secs = 20)
        !res.reconciled && (alert("RECONCILE FAILED [$mode] (bitdollar-crypto)"; level = :critical); halt!(ctrl, "reconcile mismatch"))
        summary = "[$mode] bitdollar-crypto; orders=$(length(res.acks)) fills=$(length(res.fills)) reconciled=$(res.reconciled) equity=$(round(Int, acct.equity))"
        @info "brash_crypto_live complete" summary; alert(summary; level = :info); return res.reconciled ? :ok : :reconcile_failed
    finally
        disconnect!(venue); close_ledger(ledger)
    end
end
if abspath(PROGRAM_FILE) == @__FILE__; main(); end
