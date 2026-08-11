# _sleeve_main.jl — generic governed driver body shared by the sleeve drivers in this repo.
# The sleeve's driver defines a `target(panel, cap) -> (; targets, prices, net, ...)` and calls
# sleeve_main(target; label=..., signal_id=..., regime=..., lookback=..., LIVE_SENTINEL=..., UNIVERSE=..., REPO=...).
# Same governed path + Layer-3 safety gate as the spine; dry-run by default via BB_DRYRUN.
using Dates, Printf

_readf(p) = isfile(p) ? (v = tryparse(Float64, strip(read(p, String))); v === nothing ? NaN : v) : NaN
_writef(p, x) = (mkpath(dirname(p)); write(p, string(x)))

function sleeve_main(target; label, signal_id, regime, lookback, LIVE_SENTINEL, UNIVERSE, REPO,
                     pool = "us", limits = SafetyLimits())
    db_path     = get(ENV, "BB_LEDGER_PATH", joinpath(REPO, "alpaca_ledger_$label.sqlite"))
    audit_path  = get(ENV, "BB_AUDIT_PATH",  joinpath(REPO, "alpaca_audit_$label.jsonl"))
    hwm_path    = get(ENV, "BB_HWM_PATH",    joinpath(homedir(), ".config", "blaquebaux", "equity_hwm_$label.txt"))
    equity_path = get(ENV, "BB_EQUITY_PATH", joinpath(homedir(), ".config", "blaquebaux", "equity_last_$label.txt"))
    (get(ENV, "ALPACA_KEY_ID", "") == "" || get(ENV, "ALPACA_SECRET_KEY", "") == "") &&
        error("Set ALPACA_KEY_ID and ALPACA_SECRET_KEY (read-only bars needed even in dry-run).")
    dryrun = get(ENV, "BB_DRYRUN", "") in ("1", "true", "yes")
    cap0 = 100_000.0

    if dryrun
        panel = panel_at(AlpacaPanelProvider(UNIVERSE; lookback = lookback)); bk = target(panel, cap0)
        @info "$label dry run" asof=panel.asof
        println("\n  $label targets:")
        for (s, w) in sort(collect(bk.net), by = x -> -abs(x[2]))
            abs(w) < 1e-4 && continue
            @printf("    %-6s %+6.1f%%  -> %+d sh @ \$%.2f\n", s, 100w, Int(get(bk.targets, s, 0.0)), get(bk.prices, s, NaN))
        end
        ok, reasons = preflight(; account_status = "ACTIVE", equity = cap0, hwm = cap0, last_equity = cap0,
            buying_power = cap0, data_fresh = (Dates.today() - panel.asof) <= Day(5), targets = bk.targets, prices = bk.prices, limits = limits)
        println("\n  DRY RUN — no venue, no orders. Gate: ", ok ? "PASS" : "ABORT: " * join(reasons, "; "))
        return ok ? :dryrun_ok : :dryrun_gate_abort
    end

    live = get(ENV, "BB_LIVE_CONFIRM", "") == LIVE_SENTINEL; paper = !live; mode = live ? "*** LIVE REAL MONEY ***" : "paper"
    @info "$(label)_live starting" mode; live && alert("$label LIVE REAL-MONEY mode engaged"; level = :critical)
    venue = AlpacaVenue(AlpacaConfig(; paper = paper))
    built = build_live_controller(; venue = venue, ledger_config = LedgerConfig(; db_path = db_path), audit_path = audit_path)
    ctrl, ledger = built.ctrl, built.ledger
    try
        connect!(venue) || (alert("ABORT [$mode]: connect failed ($label)"; level = :critical); return :connect_failed)
        acct = account_info(venue); acct === nothing && (alert("ABORT [$mode]: no account ($label)"; level = :critical); return :no_account)
        cap = acct.equity; hwm = max(load_hwm(hwm_path), acct.equity); last_eq = _readf(equity_path)
        panel = panel_at(AlpacaPanelProvider(UNIVERSE; lookback = lookback)); fresh = (Dates.today() - panel.asof) <= Day(5)
        bk = target(panel, cap)
        ok, reasons = preflight(; account_status = acct.status, trading_blocked = acct.trading_blocked, account_blocked = acct.account_blocked,
            equity = acct.equity, hwm = hwm, last_equity = last_eq, buying_power = acct.buying_power, data_fresh = fresh, targets = bk.targets, prices = bk.prices, limits = limits)
        save_hwm(hwm, hwm_path); _writef(equity_path, acct.equity)
        !ok && (msg = "SAFETY ABORT [$mode] ($label): " * join(reasons, "; "); @error msg; halt!(ctrl, "safety gate"); alert(msg; level = :critical); return :aborted)
        reset_daily!(ctrl); set_pool_budget!(ctrl, pool, limits.max_gross_leverage * acct.equity); set_pool_loss_limit!(ctrl, pool, limits.max_daily_loss)
        set_pool_staleness!(ctrl, pool, Day(5)); feed_staleness!(ctrl, pool; stale = !fresh); isfinite(last_eq) && update_pnl!(ctrl, pool, acct.equity - last_eq)
        ncanc = cancel_all_open!(venue); ncanc > 0 && sleep(2)
        for (sym, qty) in positions(venue, ctrl.account); apply_fill!(ctrl, sym, qty); end
        res = execute_rebalance!(ctrl, ledger; targets = bk.targets, prices = bk.prices, signal_id = signal_id, regime = regime,
            solve_id = Dates.format(panel.asof, "yyyymmdd"), pool_id = pool, settle_secs = 20)
        !res.reconciled && (alert("RECONCILE FAILED [$mode] ($label)"; level = :critical); halt!(ctrl, "reconcile mismatch"))
        summary = "[$mode] $label; orders=$(length(res.acks)) fills=$(length(res.fills)) reconciled=$(res.reconciled) equity=$(round(Int, acct.equity))"
        @info "$(label)_live complete" summary; alert(summary; level = :info); return res.reconciled ? :ok : :reconcile_failed
    finally
        disconnect!(venue); close_ledger(ledger)
    end
end
