#!/usr/bin/python3
# =============================================================================
# _brash_common.py — shared helpers for the Blaque Baux Brash (aggression) sketches.
# The growth-vs-ruin / Kelly-leverage lab. Alpaca crypto (BTC/ETH) + stock ETFs.
# Reads ALPACA_KEY_ID / ALPACA_SECRET_KEY from env. Read-only.
# =============================================================================
import os, json, urllib.request, math
from urllib.parse import quote
import numpy as np

H = {"APCA-API-KEY-ID": os.environ["ALPACA_KEY_ID"], "APCA-API-SECRET-KEY": os.environ["ALPACA_SECRET_KEY"]}
PPY = 365       # crypto trades 7 days/week
FIN = 0.065     # financing on the borrowed part of a levered position
_cache = {}

def cbars(s):
    if s in _cache: return _cache[s]
    u = ("https://data.alpaca.markets/v1beta3/crypto/us/bars?symbols=" + quote(s) +
         "&timeframe=1Day&start=2021-01-01&end=2026-08-01&limit=10000")
    d = json.load(urllib.request.urlopen(urllib.request.Request(u, headers=H), timeout=40)).get("bars", {}).get(s, [])
    _cache[s] = {b["t"][:10]: b["c"] for b in d}
    return _cache[s]

def sbars(s):
    if s in _cache: return _cache[s]
    u = (f"https://data.alpaca.markets/v2/stocks/bars?symbols={s}&timeframe=1Day"
         f"&start=2016-01-01&end=2026-08-01&adjustment=all&feed=sip&limit=10000")
    d = json.load(urllib.request.urlopen(urllib.request.Request(u, headers=H), timeout=40)).get("bars", {}).get(s, [])
    _cache[s] = {b["t"][:10]: b["c"] for b in d}
    return _cache[s]

def ewma_vol(r, hl=30, ppy=PPY):
    lam = 0.5 ** (1 / hl); v = r[0] ** 2; o = np.empty(len(r))
    for t in range(len(r)):
        v = r[t] ** 2 if t == 0 else lam * v + (1 - lam) * r[t] ** 2
        o[t] = math.sqrt(max(v, 1e-12)) * math.sqrt(ppy)
    return o

def gr(r, ppy=PPY):
    """CAGR, maxDD, ruined? (ruin = any daily loss >= 100%)."""
    r = np.asarray(r, float)
    if (1 + r).min() <= 0: return (float('nan'), -1.0, True)
    cum = np.cumprod(1 + r)
    return (cum[-1] ** (ppy / len(r)) - 1, (cum / np.maximum.accumulate(cum) - 1).min(), False)

def sharpe(r, ppy=PPY):
    r = np.asarray(r, float); return r.mean() / r.std() * math.sqrt(ppy)

def crypto_edge(tgt=0.30, cap=2.0):
    """The real edge: BTC+ETH trend + vol-target (the BitDollar keeper), used here as the
    asset to study aggression on. Returns the daily P&L series (crypto-native, ppy=365)."""
    def trend_vt(P, r):
        lvl = np.cumprod(1 + r); sig = np.full(len(r), np.nan)
        for t in range(120, len(r)):
            sig[t] = np.mean([np.sign(lvl[t] / lvl[t - h] - 1) for h in (30, 60, 120)])
        sc = np.clip(tgt / np.maximum(ewma_vol(r), 1e-6), 0, cap)
        return (sig * sc)[:-1] * r[1:]
    btc = cbars("BTC/USD"); eth = cbars("ETH/USD"); d = sorted(set(btc) & set(eth))
    Pb = np.array([btc[x] for x in d]); Pe = np.array([eth[x] for x in d])
    tb = trend_vt(Pb, Pb[1:] / Pb[:-1] - 1); te = trend_vt(Pe, Pe[1:] / Pe[:-1] - 1)
    n = min(len(tb), len(te)); e = 0.5 * tb[-n:] + 0.5 * te[-n:]
    return e[np.isfinite(e)]

def mc_terminal(r, ppy, L=1, fin=FIN, npaths=4000, block=20):
    """1-year terminal wealth from $1, block-bootstrap, levered L with financing."""
    rng = np.random.default_rng(7); r = np.asarray(r); out = np.empty(npaths)
    for i in range(npaths):
        idx = []
        while len(idx) < ppy:
            s = rng.integers(0, len(r) - block); idx += list(range(s, s + block))
        path = L * r[np.array(idx[:ppy])] - (L - 1) * fin / ppy
        out[i] = np.prod(1 + np.maximum(path, -0.999))
    return out
