#!/usr/bin/env bash
# 🧱 C13B0⁴ — Centurion Bot Spawner
# Iterative Growth Engine: ⚙️🕹️🧲🦾💎👑
# Goal: 100 repositories

set -euo pipefail

USER="${GITHUB_USER:-www-infinity}"
TOTAL_GOAL=100
DIR="c13b0_evolution_chamber"
mkdir -p "$DIR/ledger"

COUNTER_FILE="$DIR/ledger/counter.txt"
if [ ! -f "$COUNTER_FILE" ]; then echo 1 > "$COUNTER_FILE"; fi
ITERATION=$(cat "$COUNTER_FILE")

if [ "$ITERATION" -gt "$TOTAL_GOAL" ]; then
    echo "👑 100 Repositories complete. Evolution achieved."
    exit 0
fi

STAMP=$(date +%s)
REPO_NAME="b55-evo-${ITERATION}-${STAMP}"

echo "🧱 Spawning Iteration $ITERATION: $REPO_NAME"

case $((ITERATION % 4)) in
    0)
       MODE="🟡 TOKEN_WALLET"
       STATUS="DATA_EXTRACTOR"
       EMOJI="💰"
       ;;
    1)
       MODE="👑 ROYAL_TREATMENT"
       STATUS="WEBSITE_BUILD"
       EMOJI="💎"
       ;;
    2)
       MODE="🤓 RESEARCH_GUIDE"
       STATUS="TRIVIA_GAMES"
       EMOJI="🔎"
       ;;
    *)
       MODE="🦾 AUTO_BOT"
       STATUS="ENGINEERING"
       EMOJI="⚙️"
       ;;
esac

mkdir -p "$DIR/repos/$REPO_NAME"
cat <<EOF > "$DIR/repos/$REPO_NAME/README.md"
# $REPO_NAME 🧱
## Status: $STATUS ($MODE)

### 🕹️ Mechanism
- **🍄 Double Content**: Research intensity x2
- **🧲 Pull Logic**: Active for next build
- **🦾 Automation**: Bot level $((ITERATION / 10 + 1))

### 💎 Facet Collection
- Preserving useful chunks from iteration $((ITERATION - 1))
- Encoding via 🧱 Hash Protection

### ⚡ Energy & 💲 Assets
- Value Strike: Gold
- Atmosphere: Aesthetics extracted
EOF

if command -v gh &>/dev/null; then
    echo "🚀 Pushing $REPO_NAME to GitHub..."
    gh repo create "$USER/$REPO_NAME" --public \
      --description "🧱 C13B0⁴ Iteration $ITERATION" || echo "⚠️ Skip gh create"

    cd "$DIR/repos/$REPO_NAME"
    git init -q
    git add .
    git commit -m "🧱 $MODE init" -q
    git branch -M main
    git remote add origin "https://github.com/$USER/$REPO_NAME.git"
    git push -u origin main -q || true
    cd - > /dev/null
fi

echo $((ITERATION + 1)) > "$COUNTER_FILE"

echo "✅ Iteration $ITERATION complete. [ $EMOJI ]"
echo "   Next: run script again, or loop: for i in \$(seq 1 $TOTAL_GOAL); do ./centurion_spawner.sh; done"
