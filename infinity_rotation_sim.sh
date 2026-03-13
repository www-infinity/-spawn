#!/usr/bin/env bash
# 🧱 C13B0 — Silver ↔ Bitcoin Research Simulator
# SAFE MODE: read-only data, historical simulation, no execution

set -euo pipefail

USER="${GITHUB_USER:-www-infinity}"
PREFIX="infinity-sim"
STAMP=$(date -u +%Y%m%d_%H%M%S)
REPO="${PREFIX}-${STAMP}"

echo "🧱 Creating research repo: $REPO"

gh repo create "$USER/$REPO" --public --confirm
git clone "https://github.com/$USER/$REPO.git"
cd "$REPO"
git checkout -b main

mkdir -p data out

# BTC USD (CoinDesk public API)
curl -s "https://api.coindesk.com/v1/bpi/currentprice/USD.json" > data/btc.json 2>/dev/null || true

cat <<EOF > data/silver.json
{"note":"Public spot data varies by source. Replace with your lawful data source if you have one."}
EOF

cat <<EOF > out/infinity_ledger.json
{
  "as_of_utc": "$(date -u +"%Y-%m-%d %H:%M:%S")",
  "mode": "simulation-only",
  "allocations": {
    "bitcoin_pct": 50,
    "silver_pct": 50
  },
  "rules": [
    "No execution",
    "No wallets",
    "No exchanges",
    "Analytics only"
  ]
}
EOF

BTC_PRICE=$(jq -r '.bpi.USD.rate_float // empty' data/btc.json 2>/dev/null || echo "N/A")
cat <<EOF > out/analysis.md
# Infinity Research — Silver ↔ Bitcoin (Simulation)

**BTC (USD):** ${BTC_PRICE}
**Silver:** See data source note

## Notes
- This repo performs **no trades**.
- Signals are **descriptive**, not prescriptive.
- Use this to study regimes, not to move markets.
EOF

cat <<'HTML' > index.html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Infinity Simulation Dashboard</title>
<style>
body{font-family:system-ui;background:#0b1220;color:#e5e7eb;padding:20px}
.card{background:#111827;padding:16px;border-radius:12px;margin-bottom:12px;border:1px solid #374151}
</style>
</head>
<body>
<h1>∞ Infinity — Silver ↔ Bitcoin (Simulation)</h1>
<div class="card"><b>Mode:</b> Simulation-only (no execution)</div>
<div class="card"><b>Purpose:</b> Research correlations and scenarios</div>
<p style="color:#9ca3af">All outputs are analytical. Nothing here places trades or touches wallets.</p>
</body>
</html>
HTML

git add .
git commit -m "🧱 C13B0: silver-btc simulation (safe)"
git push origin main

gh api -X POST "repos/$USER/$REPO/pages" \
  -f source.branch=main -f source.path=/ || true

echo "✅ Done. Pages will be available at:"
echo "   https://$USER.github.io/$REPO/"
