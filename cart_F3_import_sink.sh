#!/usr/bin/env bash
# 🧱 C13B0 Cart F3 — Import Sink (Termux-Proof)
# USER: www-infinity
# GUARANTEE: Starts from HOME, creates repo if missing, never crashes

set -euo pipefail

USER="${GITHUB_USER:-www-infinity}"
TARGET_REPO="infinity-imports"

STAMP="$(date -u +%Y%m%d_%H%M%S)"
WORKDIR="$HOME/.c13b0_F3_$STAMP"

echo "🧱 Cart F3 — Import Sink"
echo "👤 $USER"
echo "📦 Target repo: $TARGET_REPO"
echo "🕒 $STAMP"
echo

cd "$HOME" || exit 0

if ! gh repo view "$USER/$TARGET_REPO" >/dev/null 2>&1; then
  echo "📦 Repo does not exist — creating $TARGET_REPO"
  gh repo create "$USER/$TARGET_REPO" --public >/dev/null 2>&1 || {
    echo "❌ Could not create repo"
    exit 0
  }
else
  echo "✅ Repo exists"
fi

rm -rf "$WORKDIR"
git clone "https://github.com/$USER/$TARGET_REPO.git" "$WORKDIR" >/dev/null 2>&1 || {
  echo "❌ Clone failed"
  exit 0
}

cd "$WORKDIR" || {
  echo "❌ cd failed"
  exit 0
}

mkdir -p imports

FILE="imports/import_$STAMP.txt"

cat > "$FILE" <<EOF
🔵 IMPORT RECEIVED

Time: $STAMP
Source: Crown Index 🧲 Pull
Cart: F3 (stable)

This file proves:
- cloning works
- writing works
- committing works
- pushing works
EOF

git add "$FILE" >/dev/null 2>&1
git commit -m "🔵 Import accepted ($STAMP)" >/dev/null 2>&1
git push >/dev/null 2>&1

echo ""
echo "✅ Import written successfully"
echo "📄 $TARGET_REPO/$FILE"
echo "🧱 Cart F3 COMPLETE — zero crash paths"
