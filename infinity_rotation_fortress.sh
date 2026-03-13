#!/usr/bin/env bash
# 🧱 C13B0⁴ — Infinity Rotation Fortress
# MODE: STRICT SIMULATION / ANALYTICS / RESEARCH ONLY
# NO TRADES • NO EXECUTION • NO MARKET INTERACTION

set -euo pipefail

USER="${GITHUB_USER:-www-infinity}"
PREFIX="c13b0-fortress-infinity"
STAMP=$(date -u +%Y%m%d_%H%M%S)
REPO="${PREFIX}-${STAMP}"

echo "🧱🔒 Initializing C13B0⁴ Fortress → $REPO"

gh repo create "$USER/$REPO" --public --confirm || echo "Repo may already exist — continuing"
git clone "https://github.com/$USER/$REPO.git" || (cd "$REPO" && git pull)
cd "$REPO"
git checkout -b main 2>/dev/null || git checkout main

mkdir -p data out assets charts

cat <<EOF > data/btc_history.csv
date,price
2024-09-01,58000
2024-10-01,62000
2024-11-01,69000
2024-12-01,92000
2025-03-01,105000
2025-06-01,88000
2025-09-01,112000
2025-12-01,145000
2026-01-01,168000
EOF

cat <<EOF > data/silver_note.json
{
  "disclaimer": "Silver data is NOT fetched or used for pricing. Simulation only.",
  "mode": "pure research abstraction"
}
EOF

cat <<'PY' > analyze.py
import csv, json, statistics

STAMP = __import__('datetime').datetime.utcnow().isoformat()

dates, prices = [], []
with open("data/btc_history.csv") as f:
    r = csv.DictReader(f)
    for row in r:
        dates.append(row["date"])
        prices.append(float(row["price"]))

n = len(prices)
if n < 3:
    print("Insufficient data")
    exit()

returns = [(prices[i] - prices[i-1]) / prices[i-1] for i in range(1, n)]
vol = statistics.stdev(returns) if len(returns) > 1 else 0.0
momentum_pct = (prices[-1] / prices[0] - 1) * 100

gains = [max(r, 0) for r in returns[-14:]]
losses = [abs(min(r, 0)) for r in returns[-14:]]
avg_gain = statistics.mean(gains) if gains else 0
avg_loss = statistics.mean(losses) if losses else 0.0001
rs = avg_gain / avg_loss
rsi = 100 - (100 / (1 + rs)) if rs else 50
accel = returns[-1] - returns[-2] if len(returns) >= 2 else 0

regime = "NEUTRAL"
rotation_strength = 0.0

if momentum_pct > 80 and vol > 0.08 and rsi > 72 and accel > 0.02:
    regime = "FORTRESS_ROTATION_PRESSURE"
    rotation_strength = 0.85
elif momentum_pct > 40 and vol > 0.06 and rsi > 65:
    regime = "ELEVATED_ROTATION_PRESSURE"
    rotation_strength = 0.65
elif momentum_pct > 0:
    regime = "RISK_ON"
    rotation_strength = 0.0
else:
    regime = "DEFENSIVE"
    rotation_strength = 0.20

base_btc = 0.60
btc_weight = base_btc * (1 - rotation_strength) + 0.40 * rotation_strength * 0.3
silver_weight = 1 - btc_weight

ledger = {
    "version": "C13B0⁴-FORTRESS",
    "mode": "STRICT_SIMULATION_ONLY",
    "timestamp_utc": STAMP,
    "regime": regime,
    "rotation_strength": round(rotation_strength, 3),
    "metrics": {
        "btc_momentum_pct": round(momentum_pct, 2),
        "btc_volatility": round(vol, 4),
        "rsi_proxy": round(rsi, 1),
        "accel_last": round(accel, 4)
    },
    "simulated_allocation_pressure": {
        "bitcoin_pct": round(btc_weight * 100, 1),
        "silver_pct": round(silver_weight * 100, 1)
    },
    "iron_rules": [
        "NO TRADING EVER", "NO EXECUTION", "NO MARKET INTERACTION",
        "RESEARCH & THOUGHT EXPERIMENT ONLY"
    ]
}

with open("out/fortress_ledger.json", "w") as f:
    json.dump(ledger, f, indent=2)

print(f"🧱🔒 Fortress: {regime} | Rotation strength: {rotation_strength:.2f}")
PY

python3 analyze.py 2>/dev/null || python analyze.py 2>/dev/null || true

cat <<'HTML' > index.html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>C13B0⁴ Fortress — Infinity Rotation Research</title>
<style>
:root { --bg:#0a0e1a; --card:#111827; --warn:#ef4444; --muted:#9ca3af; }
body { background:var(--bg); color:#e5e7eb; font-family:system-ui; padding:32px; line-height:1.6; }
.card { background:var(--card); padding:24px; border-radius:16px; margin:24px 0; border:1px solid #1f2937; }
.warn { color:var(--warn); font-weight:bold; }
.badge { padding:8px 14px; border-radius:999px; background:#1f2937; font-size:0.9rem; }
</style>
</head>
<body>
<h1>🧱🔒 C13B0⁴ — Infinity Rotation Fortress</h1>
<div class="card">
  <span class="badge">SIMULATION &amp; RESEARCH ONLY</span>
  <p class="warn">THIS IS NOT FINANCIAL ADVICE. NO TRADING. NO SIGNALS. NO EXECUTION.</p>
</div>
<div class="card">
  <h2>Purpose</h2>
  <p>Explore hypothetical volatility-adjusted momentum regimes and abstract allocation pressure. Pure thought experiment.</p>
</div>
<div class="card">
  <h2>Absolute Rules</h2>
  <ul>
    <li>NO market interaction of any kind</li>
    <li>NO trades or trade signals</li>
    <li>NO enforcement or real-world application</li>
    <li>Outputs are analytical fiction only</li>
  </ul>
</div>
<p style="color:var(--muted)">See out/fortress_ledger.json for machine output.</p>
</body>
</html>
HTML

git add .
git commit -m "🧱🔒 C13B0⁴: Fortress edition — stronger rotation simulation (analytics only)"
git push origin main

gh api -X POST "repos/$USER/$REPO/pages" \
  -f source.branch=main -f source.path=/ || true

echo "✅ C13B0⁴ FORTRESS DEPLOYED"
echo "🌐 https://$USER.github.io/$REPO/"
