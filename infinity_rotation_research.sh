#!/usr/bin/env bash
# 🧱 C13B0² — Infinity Rotation Research Cart
# MODE: STRICT SIMULATION / ANALYTICS ONLY
# No trades • No execution • No enforcement • No market interaction

set -euo pipefail

USER="${GITHUB_USER:-www-infinity}"
PREFIX="infinity-rotation-research"
STAMP=$(date -u +%Y%m%d_%H%M%S)
REPO="${PREFIX}-${STAMP}"

echo "🧱 Initializing C13B0² cart → $REPO"

gh repo create "$USER/$REPO" --public --confirm
git clone "https://github.com/$USER/$REPO.git"
cd "$REPO"
git checkout -b main

mkdir -p data out assets

cat <<EOF > data/btc_history.csv
date,price
2024-09-01,60000
2024-10-01,62000
2024-11-01,58000
2024-12-01,65000
2025-01-01,68000
EOF

cat <<EOF > data/silver_note.json
{
  "note": "Silver prices vary by venue. This model simulates allocation pressure only.",
  "sources": ["LBMA", "COMEX", "ETF proxies"],
  "mode": "non-price, non-trading"
}
EOF

cat <<'PY' > analyze.py
import csv, json, statistics

prices = []
with open("data/btc_history.csv") as f:
    r = csv.DictReader(f)
    for row in r:
        prices.append(float(row["price"]))

returns = [(prices[i]-prices[i-1])/prices[i-1] for i in range(1, len(prices))]
vol = statistics.stdev(returns) if len(returns) > 1 else 0
momentum = prices[-1] - prices[0]

if momentum > 5000 and vol > 0.05:
    regime = "ROTATION_PRESSURE"
elif momentum > 0:
    regime = "RISK_ON"
else:
    regime = "DEFENSIVE"

btc = 0.6
silver = 0.4
if regime == "ROTATION_PRESSURE":
    btc = 0.45
    silver = 0.55

ledger = {
    "mode": "simulation-only",
    "regime": regime,
    "btc_volatility": round(vol, 4),
    "btc_momentum_usd": momentum,
    "simulated_allocation": {
        "bitcoin_pct": round(btc*100, 1),
        "silver_pct": round(silver*100, 1)
    },
    "rules": ["No trading", "No execution", "No market interaction", "Analytics only"]
}

with open("out/infinity_ledger.json", "w") as f:
    json.dump(ledger, f, indent=2)

print("🧱 Analysis complete:", regime)
PY

python3 analyze.py 2>/dev/null || python analyze.py 2>/dev/null || true

cat <<'CSS' > assets/style.css
:root { --bg:#0b1220; --card:#111827; --muted:#9ca3af; }
body { background:var(--bg); color:#e5e7eb; font-family:system-ui; padding:24px }
nav a { margin-right:14px; color:#93c5fd; text-decoration:none; font-weight:500 }
.card { background:var(--card); padding:16px; border-radius:14px; margin-bottom:14px; border:1px solid #374151 }
.small { color:var(--muted); font-size:13px }
.badge { padding:6px 10px; border-radius:999px; background:#1f2937 }
CSS

NAV='<nav><a href="index.html">Overview</a><a href="methodology.html">Methodology</a><a href="regimes.html">Regimes</a><a href="scenarios.html">Scenarios</a><a href="ethics.html">Ethics</a></nav>'

cat <<HTML > index.html
<!doctype html><html lang="en"><head>
<meta charset="utf-8"><title>Infinity Rotation Research</title>
<link rel="stylesheet" href="assets/style.css">
</head><body>
${NAV}
<h1>∞ Bitcoin → Silver Rotation</h1>
<div class="card"><b>Status:</b> <span class="badge">Simulation Only</span></div>
<div class="card"><b>Purpose</b><p>Study volatility-adjusted momentum and hypothetical allocation pressure.</p></div>
<div class="card small">No trading. No execution. No market influence.</div>
</body></html>
HTML

cat <<HTML > methodology.html
<!doctype html><html lang="en"><head>
<meta charset="utf-8"><title>Methodology</title>
<link rel="stylesheet" href="assets/style.css">
</head><body>
${NAV}
<h1>Methodology</h1>
<div class="card"><ul>
<li>Public historical price inputs</li>
<li>Return &amp; volatility computation</li>
<li>Momentum-based regime mapping</li>
<li>Allocation pressure (not price)</li>
</ul></div>
</body></html>
HTML

cat <<HTML > regimes.html
<!doctype html><html lang="en"><head>
<meta charset="utf-8"><title>Regimes</title>
<link rel="stylesheet" href="assets/style.css">
</head><body>
${NAV}
<h1>Regime Logic</h1>
<div class="card"><table>
<tr><td>RISK_ON</td><td>Positive momentum</td></tr>
<tr><td>ROTATION_PRESSURE</td><td>High momentum + volatility</td></tr>
<tr><td>DEFENSIVE</td><td>Negative momentum</td></tr>
</table></div>
</body></html>
HTML

cat <<HTML > scenarios.html
<!doctype html><html lang="en"><head>
<meta charset="utf-8"><title>Scenarios</title>
<link rel="stylesheet" href="assets/style.css">
</head><body>
${NAV}
<h1>Scenario Explorer</h1>
<div class="card"><p>Manual hypothetical inputs only. No live data.</p></div>
</body></html>
HTML

cat <<HTML > ethics.html
<!doctype html><html lang="en"><head>
<meta charset="utf-8"><title>Ethics</title>
<link rel="stylesheet" href="assets/style.css">
</head><body>
${NAV}
<h1>Ethics &amp; Compliance</h1>
<div class="card"><ul>
<li>No trading</li>
<li>No enforcement</li>
<li>No asset seizure</li>
<li>No market manipulation</li>
<li>Research and planning only</li>
</ul></div>
</body></html>
HTML

git add .
git commit -m "🧱 C13B0²: Infinity rotation research site (simulation-only)"
git push origin main

gh api -X POST "repos/$USER/$REPO/pages" \
  -f source.branch=main -f source.path=/ || true

echo "✅ C13B0² COMPLETE"
echo "🌐 https://$USER.github.io/$REPO/"
