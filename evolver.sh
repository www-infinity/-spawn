#!/usr/bin/env bash
# 🧱 C13B0⁴ — COMMAND-DRIVEN SPAWNER
# Usage: ./evolver.sh [COUNT]   (default: 1)

set -euo pipefail

USER="${GITHUB_USER:-www-infinity}"
DIR="./c13b0_evolution_chamber"
mkdir -p "$DIR/ledger"

BATCH_SIZE=${1:-1}

COUNTER_FILE="$DIR/ledger/global_total.txt"
if [ ! -f "$COUNTER_FILE" ]; then echo 0 > "$COUNTER_FILE"; fi

echo "🧱 Starting batch of $BATCH_SIZE builds..."

for (( i=1; i<=BATCH_SIZE; i++ )); do
    TOTAL=$(($(cat "$COUNTER_FILE") + 1))
    echo "$TOTAL" > "$COUNTER_FILE"

    STAMP=$(date +%s)
    REPO_NAME="b55-evo-v${TOTAL}-${STAMP}"

    case $((TOTAL % 5)) in
        0) TAG="👑 ROYAL"; EMOJI="👑";;
        1) TAG="🟡 TOKEN"; EMOJI="🟡";;
        2) TAG="💎 FACET"; EMOJI="💎";;
        3) TAG="🦾 BOTS";  EMOJI="🦾";;
        *) TAG="⚙️ BUILD"; EMOJI="⚙️";;
    esac

    echo "🏗️  ($i/$BATCH_SIZE) Minting: $REPO_NAME [$EMOJI]"

    mkdir -p "$DIR/repos/$REPO_NAME"

    cat > "$DIR/repos/$REPO_NAME/README.md" <<EOF
# $EMOJI $REPO_NAME
## Mode: $TAG (Iteration $TOTAL)
### 🕹️ Search: Forward & Reverse Quantum 🔍🟪🔎
### 🍄 Content: DOUBLED
Generated on: $(date)
EOF

    if command -v gh &>/dev/null; then
        gh repo create "$USER/$REPO_NAME" --public \
          --description "🧱 C13B0⁴ #$TOTAL" --confirm || true

        cd "$DIR/repos/$REPO_NAME"
        git init -q
        git add .
        git commit -m "🧱 $TAG init" -q
        git branch -M main
        git remote add origin "https://github.com/$USER/$REPO_NAME.git"
        git push -u origin main -q
        cd - > /dev/null
    fi

    sleep 1
done

echo "✅ Done. Global count is now: $(cat "$COUNTER_FILE")"
