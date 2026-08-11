#!/usr/bin/env julia
# ============================================================================
# brash_live.jl — BLAQUE BAUX BRASH live driver (fractional-Kelly crypto trend).
#
# Runs on the engine (engine/ submodule) — same governed order path + Layer-3 safety gate as the spine.
# Brash's keeper is not a new strategy but a SIZING DISCIPLINE: the crypto-trend edge sized at
# FRACTIONAL KELLY (~1.5x) with a vol-target as the governor (no drawdown brake — it over-de-risks
# crypto's V-recoveries). Research laws: levered CAGR peaks at ~2x (Kelly 2.4x) then declines while
# drawdown explodes; the vol-target caps position size in high vol so ruin stays ~0% even at 3x. So this
# is bitdollar's edge, sized AGGRESSIVELY — a higher vol-target (25%) capped at 1.5x gross.
#
# CAVEATS (honest): same crypto edge as bitdollar (overlapping remit); one crypto cycle of history;
# aggressive by design (bigger drawdowns). Traded via spot ETFs IBIT (BTC) + ETHA (ETH).
#
# MODES: dry-run by default via the wrapper (BB_DRYRUN=1). Real money needs BB_LIVE_CONFIRM. Kill
# switch: ~/.config/blaquebaux/HALT.  Run: julia --project=engine live/brash_live.jl.  Not validated to the spine's bar.
# ============================================================================
using Dates, Printf, Statistics

const REPO   = normpath(joinpath(@__DIR__, ".."))
const ENGINE = joinpath(REPO, "engine")
for m in ("module_7_execution/module_7_execution.jl","module_10_feedback/module_10_feedback.jl",
          "module_13_portfolio/module_13_portfolio.jl","module_1_data/equity_panel.jl",
          "module_1_data/alpaca_panel.jl","module_8_governance/safety_gate.jl")
    include(joinpath(ENGINE, "src", m))
end
using .ExecutionLayer, .FeedbackLayer, .PortfolioOptModule, .EquityPanel, .AlpacaPanel, .SafetyGate
include(joinpath(ENGINE, "scripts/live_execution.jl"))
include(joinpath(@__DIR__, "_sleeve_main.jl"))

const ASSETS = ["IBIT", "ETHA"]
const UNIVERSE = ASSETS
const LIVE_SENTINEL = "I_UNDERSTAND_THIS_IS_REAL_MONEY"
const VOL_TARGET = 0.25                            # aggressive (fractional-Kelly) sizing
const CAP_GROSS = 1.5

function ewma_vol_ann(r; hl = 20)
    isempty(r) && return NaN; lam = 0.5^(1/hl); v = float(r[1])^2
    for t in eachindex(r); v = t == 1 ? float(r[t])^2 : lam*v + (1-lam)*float(r[t])^2; end
    sqrt(max(v, 1e-12)) * sqrt(252)
end

function brash_target(panel, cap)                  # crypto trend at fractional-Kelly sizing
    syms = panel.symbols; R = panel.returns; T = size(R, 1)
    col(s) = R[:, findfirst(==(s), syms)]; px(s) = panel.prices[findfirst(==(s), syms)]
    net = Dict{String,Float64}(); price = Dict{String,Float64}()
    for a in ASSETS
        r = col(a); frac = mean([(prod(1 .+ r[T-h+1:T]) - 1) > 0 ? 1.0 : 0.0 for h in (30, 60, 120)])
        net[a] = frac * (VOL_TARGET / max(ewma_vol_ann(r; hl = 20), 1e-6)) / length(ASSETS); price[a] = px(a)
    end
    g = sum(abs, values(net)); g > CAP_GROSS && for a in keys(net); net[a] *= CAP_GROSS / g; end
    (targets = Dict(a => round(Float64, net[a] * cap / price[a]) for a in ASSETS), prices = price, net = net, gross = sum(abs, values(net)))
end

if abspath(PROGRAM_FILE) == @__FILE__
    sleeve_main(brash_target; label = "brash", signal_id = "brash", regime = "crypto-trend-aggressive",
        lookback = 220, LIVE_SENTINEL = LIVE_SENTINEL, UNIVERSE = UNIVERSE, REPO = REPO)
end
