# Blaque Baux Brash

**Deliberately aggressive. Crypto and alternatives, sized for convex upside — governed so aggression never becomes uncontrolled ruin.**

Brash is a member of the Blaque Baux family. The [core repo](https://github.com/blaquebaux/base)
is the **engine and blueprint**: a governed, systematic platform (Julia) with a
venue-agnostic execution controller and a Layer-3 live-money safety gate. Brash points
that engine at the high-octane end of the market — crypto, leverage, alternative and
convex exposures — while inheriting the engine's governance wholesale. **Aggression here
is a sizing decision, never a governance bypass:** every order still routes through the
same idempotency, reconciliation, kill switch, and drawdown/loss gates as the spine.

> **Not investment advice.** Educational/research software. Aggressive strategies carry
> outsized risk, including total loss. Nothing here is validated. See [LICENSE](LICENSE).

```bash
git clone --recursive https://github.com/blaquebaux/brash.git
julia --project=engine -e 'using Pkg; Pkg.instantiate()'   # one-time engine setup
```

## The thesis

The base research already mapped the growth-vs-ruin frontier: **aggression multiplies
edge, and with no edge it multiplies only ruin** (see the base's `growth_vs_ruin` sketch —
levering a ~1.0-Sharpe book past its Kelly point *lowers* growth while deepening drawdown).
Brash takes the honest implication seriously: pursue convex, high-return sleeves, but cap
them at a hard ruin boundary the governance layer enforces. The goal is asymmetric upside
with a floor, not maximal leverage.

## Research plan (Path A — not yet built)

Candidate directions to test with the same discipline as the base corpus (build it, test
it honestly, keep the record including what fails):

- **Crypto trend / vol-targeting** — BTC/ETH time-series momentum, each vol-targeted; the
  base already ingests Deribit BTC implied vol as a risk input.
- **Kelly-capped leverage** — size by fractional Kelly with a hard ruin cap; measure
  terminal-wealth distributions (block-bootstrap), not just Sharpe.
- **Crypto funding / basis carry** — perp funding and spot-futures basis, with the honest
  caveat (from the base's carry work) that carry is negative-skew and can be un-timeable.
- **Alternative / convex sleeves** — asymmetric payoffs where the downside is defined.

## Research — first pass done

Full detail in [`research/README.md`](research/README.md). Brash's job is **aggression,
governed** — the growth-vs-ruin / Kelly-leverage lab. The scorecard:

| # | Finding |
|---|---------|
| 1a | **The Kelly ceiling** — even on a strong edge, levered CAGR peaks at ~2× (Kelly 2.4×) then declines; negative past ~6× |
| 1b | **Edge determines safe leverage** — strong edge tolerates 2–3×; weak edge ruins by 2×; negative edge (VIXY) annihilated |
| 2 | **Vol-target is the governor** — 0% ruin even at 3×; VIXY median 1-yr $0.48; a drawdown brake over-de-risks crypto |

**The synthesis:** aggression is a *distribution* choice, not a Sharpe choice. Even on the
crypto-trend edge (Sharpe 0.83), full-Kelly (~2×) doubles the drawdown for a few % more CAGR,
and beyond it growth *falls* while ruin explodes — "aggression multiplies edge; with none it
multiplies only ruin" (BTC buy&hold ruins by 2×; VIXY is annihilated at any leverage). The
aggressive keeper is the crypto-trend edge sized at **fractional Kelly with a vol-target** —
the rule for being aggressive safely, not a new strategy. Reserve max aggression (VIXY-type
convex bets) for nothing: they bleed (median 1-yr outcome $0.48). Caveat: the Kelly estimate
is from one crypto cycle (2021–2026) — an upper bound, not a target.

## Status
**Research: first pass complete — the aggression discipline; standalone driver built** (`research/` +
`live/`). The keeper is governed leverage on the crypto-trend edge (fractional Kelly + vol-target).
`live/brash_live.jl` runs it standalone through the engine's order path + Layer-3 safety gate: the
crypto-trend edge (IBIT/ETHA) sized aggressively — a 25% vol-target capped at 1.5× gross. **Dry-run by
default**; graduates to paper with its own isolated keys. Aggressive by design (overlaps bitdollar's
edge); not validated to the spine's bar.

**Validation:** the equity-rail gate FAILS on the spot ETF proxy (OOS Sharpe −0.69, ETFs only since
2024), but the *actual* crypto-trend thesis PASSES on the real BTC/USD + ETH/USD rail — aggressive
sizing **+0.72 Sharpe / +10% CAGR / −20% maxDD** (2021–2026, net of cost) vs buy-and-hold +0.29 / −76%.
The edge is real; the proxy is the problem. See `blaquebaux-bitdollar` → `research/bitdollar_crypto_validation.py`
(shared crypto edge).

**Crypto execution is now wired** — [`live/brash_crypto_live.jl`](live/brash_crypto_live.jl) trades the
aggressive crypto-trend edge on the **real BTC/USD + ETH/USD rail** (fractional orders, 25% vol-target
capped at 1.5× gross) through the same Layer-3 safety gate + reconcile as the spine. **Dry-run by
default**. The ETF-proxy driver (`brash_live.jl`) remains for equity-only accounts.
```bash
BB_DRYRUN=1 julia --project=engine live/brash_crypto_live.jl   # real BTC/ETH, aggressive, no orders
```
```bash
BB_DRYRUN=1 julia --project=engine live/brash_live.jl
```

## About Blaque Baux

**Blaque Baux** is a quantitative research initiative and a subsidiary of **[Carter Warrens](https://carterwarrens.com)**.
[**BlaqueBaux.com**](https://blaquebaux.com) is the home for the work; the code lives here on GitHub — open to
study, test, and build bespoke strategies on top of.

Anyone can point an AI at a market. The edge is **understanding what the data actually says — and turning it
into something you can act on.** We test relentlessly and put most of it *on the record as rejected, with the
reason*; what survives is built, governed, and validated before it is ever called real. That combination —
honest research, reproducible evidence, and execution you can trust — is why Carter Warrens leads on
**strategy and implementation**, not merely uses the tools everyone now has.

## The Blaque Baux family
This repo is one sleeve of the **Blaque Baux** family — a single governed engine steered in
many directions. The [core repo](https://github.com/blaquebaux/base) is the
base/blueprint and holds the [full family roster](https://github.com/blaquebaux/base#the-blaquebaux-family).

## Layout
```
engine/     the Blaque Baux platform (git submodule → blaquebaux/base)
research/   two Path-A sketches (Kelly frontier, terminal-wealth/ruin) + scorecard
live/       governed live drivers (once a sleeve graduates to paper A/B)
```

## BLAQUE BAUX
Explore the [production site](https://www.blaquebaux.com/), [interactive LABS](https://www.blaquebaux.com/labs/), and [open research CORPUS](https://www.blaquebaux.com/corpus/).

## License
[MIT](LICENSE). © 2026 Carter Warrens.
