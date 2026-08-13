# Blaque Baux Brash — research

First-pass Path-A research on the aggressive sleeve. Brash's distinctive job is **aggression,
governed** — the growth-vs-ruin / Kelly-leverage lab, extending the base's `growth_vs_ruin`.
(Crypto trend itself is the [BitDollar](https://github.com/blaque-baux/bitdollar)
keeper; here it is the *edge* we study aggression on.) All sketches read Alpaca crypto + stock
bars, are read-only, print their own results.

```bash
export $(grep -v '^#' ~/.config/blaquebaux/alpaca.env | xargs)   # or source it
python research/brash_1_kelly_frontier.py     # how much leverage is optimal?
python research/brash_2_terminal_wealth.py    # the ruin distributions
```

## Scorecard

| # | Question | Result |
|---|----------|--------|
| 1a | Where is Kelly on a real edge? | CAGR peaks at **~2×**, then declines; negative past ~6× |
| 1b | Does leverage help without an edge? | strong edge tolerates 2–3×; weak edge ruins by 2×; **negative edge annihilated** |
| 2 | What does aggression do to the distribution? | vol-target → **0% ruin even at 3×**; VIXY median **$0.48** (loses half) |
| 2 | Best governor? | fractional Kelly + **vol-target**; a drawdown brake over-de-risks crypto |

## The synthesis — aggression is a distribution choice, not a Sharpe choice

Brash is not one strategy; it is the **discipline** for the whole family's aggressive plays.
Three quantified laws:

- **The Kelly ceiling.** Even on a strong edge (crypto trend, Sharpe 0.83), levered CAGR
  peaks at ~2× (Gaussian Kelly 2.4×) and then *declines* while drawdown explodes: +22%/−36%
  at 2×, but +5%/−75% at 5× and **negative** past 6×. Beyond Kelly you add ruin for *less*
  growth — and even full Kelly doubles the drawdown (−36% vs −18%) for a few % more CAGR, so
  the sane operating point is **fractional Kelly (~1–1.5×)**.

- **The edge determines safe leverage** (the base law, quantified): "aggression multiplies
  edge; with none it multiplies only ruin."

  | asset | 1× Sharpe | 1× / 2× / 3× CAGR |
  |---|---|---|
  | crypto trend (edge) | +0.83 | +17% / +22% / +22% |
  | BTC buy&hold (weak edge) | +0.52 | +15% / −12% / −53% |
  | VIXY long-vol (negative edge) | −0.58 | −49% / −84% / −97% |

- **Aggression lives in the tails, and the vol-target is the governor.** Block-bootstrap MC
  of 1-year terminal wealth: the vol-targeted crypto edge has **0% ruin even at 3×** (position
  size caps in high vol, so it cannot wipe out), and 3× buys upside optionality (20% chance of
  >2×) at the cost of a deeper P5 ($0.48). VIXY — the max-aggressive long-vol lottery — is a
  wealth *destroyer*: median 1-year outcome **$0.48**. And for crypto's sharp V-recoveries a
  drawdown *brake* over-de-risks (cuts leverage into the recovery, Sharpe 0.63 → 0.34) — the
  vol-target alone is the right governor.

**Where this leaves Brash:** the aggressive "keeper" is the crypto-trend edge sized at
**fractional Kelly with a vol-target** — not a new strategy, but the *rule* for being
aggressive safely. Reserve maximum aggression (VIXY-type convex bets) for nothing: they bleed.
Honest caveat: the Kelly estimate is from **one crypto cycle** (2021–2026), so it is
sample-specific — use it as an upper bound, not a target.

## Files
- `_brash_common.py` — shared crypto/stock fetch, the crypto edge, growth/ruin metrics, and MC.
- `brash_1_kelly_frontier.py` — the Kelly frontier and the edge-determines-leverage law.
- `brash_2_terminal_wealth.py` — ruin distributions (block-bootstrap MC) and governed aggression.
