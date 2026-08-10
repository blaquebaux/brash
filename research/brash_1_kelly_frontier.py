#!/usr/bin/python3
# =============================================================================
# brash_1_kelly_frontier.py — BLAQUE BAUX BRASH #1 (the growth-vs-ruin frontier).
#
# Brash is aggression, governed. This is the lab: how much leverage is optimal on a REAL
# edge (the crypto trend+vol-target keeper), and how the answer depends on the edge itself.
# TWO findings, both extending the base's growth_vs_ruin work:
#   (a) THE KELLY CEILING. Even with a strong edge, CAGR peaks at ~2x (Kelly) and then
#       DECLINES while drawdown explodes; past ~6x, growth goes negative. Beyond Kelly you
#       add ruin for LESS growth.
#   (b) THE EDGE DETERMINES SAFE LEVERAGE. A strong edge (crypto trend, Sharpe 0.83)
#       tolerates 2-3x; a weak edge (BTC buy&hold, 0.50) ruins by 2x; a NEGATIVE edge
#       (VIXY, -0.58) is annihilated by any leverage. Aggression multiplies edge; with none
#       it multiplies only ruin.
#
# RESULTS AS TESTED (crypto 2021-2026, financing 6.5%):
#   lever the edge:  1x +17%/-18 | 2x +22%/-36 | 3x +22%/-51 | 5x +5%/-75 | 6x -9%/-85
#     Kelly-optimal 2x ; Gaussian Kelly (mu-f)/sig^2 = 2.4x
#   edge table (CAGR at 1x/2x/3x):
#     crypto trend (0.83):  +17% / +22% / +22%
#     BTC buy&hold (0.52):  +15% / -12% / -53%
#     VIXY long-vol (-0.58): -49% / -84% / -97%
# CAVEAT: ONE crypto cycle -> the Kelly estimate is sample-specific. Read-only.
# =============================================================================
import os, sys, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _brash_common import crypto_edge, cbars, sbars, gr, sharpe, FIN, PPY

edge = crypto_edge()
print("=" * 72, "\nBRASH #1 — the growth-vs-ruin / Kelly frontier\n" + "=" * 72)
print(f"edge = crypto trend+vol-target: Sharpe {sharpe(edge):+.2f}, CAGR {gr(edge)[0]*100:+.0f}%, maxDD {gr(edge)[1]*100:.0f}%\n")
print("(a) lever the edge — growth peaks at Kelly, then ruin:")
print(f"    {'lev':>5}{'CAGR':>9}{'maxDD':>8}")
best = (None, -9)
for L in [1, 1.5, 2, 3, 4, 5, 6, 8]:
    c, dd, ruin = gr(L * edge - (L - 1) * FIN / PPY)
    if not ruin and c > best[1]: best = (L, c)
    print(f"    {L:>4.1f}x{('   wiped' if ruin else f'{c*100:>+8.0f}%')}{('' if ruin else f'{dd*100:>7.0f}%')}")
mu, sig = edge.mean() * PPY, edge.std() * math.sqrt(PPY)
print(f"    Kelly-optimal (max CAGR): {best[0]}x  |  Gaussian Kelly (mu-f)/sig^2: {(mu-FIN)/sig**2:.1f}x")

print("\n(b) the edge determines safe leverage:")
btc = cbars("BTC/USD"); dk = sorted(btc); Pb = np.array([btc[x] for x in dk]); bh = Pb[1:] / Pb[:-1] - 1
vx = sbars("VIXY"); dv = sorted(vx); Pv = np.array([vx[x] for x in dv]); rv = Pv[1:] / Pv[:-1] - 1
for nm, s, ppy in [("crypto trend (edge)", edge, PPY), ("BTC buy&hold (weak edge)", bh, PPY), ("VIXY long-vol (neg edge)", rv, 252)]:
    row = f"    {nm:<26} 1x/2x/3x CAGR:"
    for L in [1, 2, 3]:
        c, dd, ruin = gr(L * s - (L - 1) * FIN / ppy, ppy)
        row += (" RUIN" if ruin else f" {c*100:+.0f}%")
    print(row + f"   (Sharpe {sharpe(s, ppy):+.2f})")
print("\nVERDICT: growth peaks at Kelly (~2x here) then declines; leverage only helps in")
print("proportion to the EDGE. Be aggressive only where the edge is strong, and size at")
print("FRACTIONAL Kelly — full Kelly already doubles the drawdown for a few % more CAGR.")
