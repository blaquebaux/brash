#!/usr/bin/python3
# =============================================================================
# brash_2_terminal_wealth.py — BLAQUE BAUX BRASH #2 (ruin distributions & governance).
#
# Sharpe hides the tails; aggression lives in them. Block-bootstrap Monte Carlo of 1-year
# terminal wealth ($1 start) shows what leverage actually does to the DISTRIBUTION:
#   - the vol-targeted crypto edge has 0% ruin even at 3x (the vol-target caps position size
#     in high vol, so it cannot wipe out) — 3x buys upside optionality (20% chance of >2x)
#     at the cost of a deeper P5;
#   - VIXY (max-aggressive long-vol) is a wealth DESTROYER: a median 1-year outcome of ~$0.48
#     (you lose half), the classic negative-carry lottery.
# And governance: for crypto's sharp V-recoveries, the vol-target IS the governor — bolting a
# drawdown BRAKE on top over-de-risks (it cuts leverage into the recovery), lowering Sharpe.
#
# RESULTS AS TESTED (2021-2026 crypto; VIXY 2016-2026):
#   1yr terminal $ : crypto trend 1x  median 1.16  P5 0.85  P95 1.65  ruin 0%  >2x 0%
#                    crypto trend 3x  median 1.18  P5 0.48  P95 3.34  ruin 0%  >2x 20%
#                    VIXY 1x          median 0.48  P5 0.21  P95 1.61  ruin 0%  >2x 3%
#   governed: full 3x +22%/-51%/Sharpe 0.63  vs  ~2x + drawdown-brake +6%/-34%/0.34
# Read-only.
# =============================================================================
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _brash_common import crypto_edge, sbars, mc_terminal, gr, sharpe, FIN, PPY

edge = crypto_edge()
vx = sbars("VIXY"); dv = sorted(vx); Pv = np.array([vx[x] for x in dv]); rv = Pv[1:] / Pv[:-1] - 1
print("=" * 72, "\nBRASH #2 — terminal-wealth distributions & governed aggression\n" + "=" * 72)
print("1-year terminal wealth from $1 (block-bootstrap, 4000 paths):")
for nm, s, ppy, L in [("crypto trend 1x", edge, PPY, 1), ("crypto trend 3x", edge, PPY, 3), ("VIXY 1x (max-aggressive)", rv, 252, 1)]:
    w = mc_terminal(s, ppy, L)
    print(f"  {nm:<26} median ${np.median(w):>5.2f}  P5 ${np.percentile(w,5):>5.2f}  P95 ${np.percentile(w,95):>6.2f}  "
          f"ruin(<$.10) {100*(w<0.1).mean():>3.0f}%  >2x {100*(w>2).mean():>3.0f}%")

print("\ngoverned aggression — for crypto, vol-target is the governor (a brake over-de-risks):")
def braked(s, L, ppy, brake=-0.20):
    cum = 1.0; peak = 1.0; out = []
    for x in s:
        dd = cum / peak - 1; lev = L * (0.4 if dd < brake else 1.0)
        rr = max(lev * x - (lev - 1) * FIN / ppy, -0.999); cum *= (1 + rr); peak = max(peak, cum); out.append(rr)
    return np.array(out)
c, dd, _ = gr(3 * edge - 2 * FIN / PPY)
print(f"  full 3x (ungoverned):        CAGR {c*100:+.0f}%  maxDD {dd*100:.0f}%  Sharpe {sharpe(3*edge-2*FIN/PPY):+.2f}")
b = braked(edge, 2, PPY); cb, ddb, _ = gr(b)
print(f"  ~2x + drawdown brake:        CAGR {cb*100:+.0f}%  maxDD {ddb*100:.0f}%  Sharpe {sharpe(b):+.2f}  (brake cuts into V-recoveries)")
print("\nVERDICT: aggression is a distribution choice, not a Sharpe choice. Size the crypto")
print("edge at fractional Kelly and let the VOL-TARGET govern the tail — it delivers upside")
print("optionality with 0% ruin. Reserve max-aggression (VIXY-type) for nothing: it bleeds.")
