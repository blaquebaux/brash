#!/usr/bin/env julia
# brash_validation.jl — validate-before-live gate for the BRASH sleeve (walk-forward / OOS / net-of-cost).
# Reuses brash_target from brash_live.jl. Run:  julia --project=engine live/brash_validation.jl
include(joinpath(@__DIR__, "brash_live.jl"))
include(joinpath(@__DIR__, "_sleeve_validation.jl"))
validate_sleeve(brash_target; label = "BRASH", universe = UNIVERSE, warmup = 150, kind = :directional)
