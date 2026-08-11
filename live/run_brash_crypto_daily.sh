#!/bin/bash
# run_brash_crypto_daily.sh — BRASH on the REAL crypto rail (BTC/USD + ETH/USD, governed,
# fractional). DRY-RUN by default (logs the fractional book, places nothing) via the shared data keys;
# graduates to PAPER once ~/.config/blaquebaux/alpaca_brash_crypto.env exists (a crypto-enabled
# account's keys). Crypto trades 24/7 -> no trading-day gate. Manual dry test:
#   BB_DRYRUN=1 bash live/run_brash_crypto_daily.sh
set -uo pipefail
REPO="/Users/malcolmx/blaquebaux-brash"; ENGINE="$REPO/engine"; JULIA="/Users/malcolmx/.juliaup/bin/julia"
DATAENV="$HOME/.config/blaquebaux/alpaca.env"; SLEEVEENV="$HOME/.config/blaquebaux/alpaca_brash_crypto.env"
LOGDIR="$REPO/logs"; mkdir -p "$LOGDIR"; LOG="$LOGDIR/brash_crypto_$(TZ=America/New_York date +%Y%m%d).log"
exec >> "$LOG" 2>&1
echo "======== $(TZ=America/New_York date '+%F %T %Z') BRASH-CRYPTO daily run ========"
export BB_LEDGER_PATH="$REPO/alpaca_ledger_brash_crypto.sqlite" BB_AUDIT_PATH="$REPO/alpaca_audit_brash_crypto.jsonl"
export BB_HWM_PATH="$HOME/.config/blaquebaux/equity_hwm_brash_crypto.txt" BB_EQUITY_PATH="$HOME/.config/blaquebaux/equity_last_brash_crypto.txt"
if [ -f "$SLEEVEENV" ]; then set -a; source "$SLEEVEENV"; set +a
else [ -f "$DATAENV" ] && { set -a; source "$DATAENV"; set +a; }; export BB_DRYRUN=1; fi
if [ -z "${ALPACA_KEY_ID:-}" ] || [ -z "${ALPACA_SECRET_KEY:-}" ]; then echo "no ALPACA keys — skipping"; exit 0; fi
MODE=$([ "${BB_DRYRUN:-}" = "1" ] && echo dryrun || echo paper); echo "mode=$MODE"
# crypto trades 24/7 — no trading-day gate; catch-up idempotency guard applies for paper
if [ "$MODE" = "paper" ]; then
  ET_TODAY=$(TZ=America/New_York date +%F)
  ORDERS_TODAY=$(curl -s --max-time 15 -H "APCA-API-KEY-ID: $ALPACA_KEY_ID" -H "APCA-API-SECRET-KEY: $ALPACA_SECRET_KEY" "https://paper-api.alpaca.markets/v2/orders?status=all&limit=10&after=${ET_TODAY}T00:00:00Z" | grep -o '"id"' | wc -l | tr -d ' ')
  [ "${ORDERS_TODAY:-0}" -gt 0 ] && { echo "already placed today — skipping (catch-up no-op)"; exit 0; }
fi
cd "$REPO" || exit 1
"$JULIA" --project="$ENGINE" "$REPO/live/brash_crypto_live.jl"; RC=$?
echo "======== done rc=$RC $(TZ=America/New_York date '+%T %Z') ========"; exit $RC
