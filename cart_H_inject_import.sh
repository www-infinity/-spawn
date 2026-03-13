#!/usr/bin/env bash
# 🧱 C13B0 Cart H — Inject Import into Target Site
# USER: www-infinity
# PURPOSE: Link imported content into a real website

set -euo pipefail

USER="${GITHUB_USER:-www-infinity}"
TARGET_REPO="${1:-infinity-spark}"
IMPORT_REPO="infinity-imports"

STAMP="$(date -u +%Y%m%d_%H%M%S)"
WORK="$HOME/.c13b0_H_$STAMP"

echo "🧱 Cart H — Inject Import into Site"
echo "👤 $USER"
echo "📦 Target site: $TARGET_REPO"
echo "📦 Import source: $IMPORT_REPO"
echo "🕒 $STAMP"
echo

cd "$HOME" || exit 0

rm -rf "$WORK"
git clone "https://github.com/$USER/$IMPORT_REPO.git" "$WORK/imports" >/dev/null 2>&1 || {
  echo "❌ Failed to clone import repo"
  exit 0
}

LATEST_PAGE="$(ls -1 "$WORK/imports/pages/"*.html 2>/dev/null | sort | tail -n 1)"

if [[ -z "$LATEST_PAGE" ]]; then
  echo "❌ No promoted import pages found — run Cart G first"
  exit 0
fi

PAGE_NAME="$(basename "$LATEST_PAGE")"
PAGE_URL="https://$USER.github.io/$IMPORT_REPO/pages/$PAGE_NAME"

echo "🔵 Using import page:"
echo "   $PAGE_URL"
echo

git clone "https://github.com/$USER/$TARGET_REPO.git" "$WORK/target" >/dev/null 2>&1 || {
  echo "❌ Failed to clone target repo"
  exit 0
}

cd "$WORK/target" || exit 0

if [[ ! -f index.html ]]; then
  cat > index.html <<EOF
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>$TARGET_REPO</title>
<style>body{font-family:system-ui;background:#0b1220;color:#e5e7eb;padding:20px}
a{color:#60a5fa}</style>
</head>
<body>
<h1>$TARGET_REPO</h1>
</body>
</html>
EOF
fi

if ! grep -q "Imported Content" index.html; then
  sed -i "s|</body>|<section>\n<h2>🔵 Imported Content</h2>\n<ul>\n<li><a href=\"$PAGE_URL\">$PAGE_NAME</a></li>\n</ul>\n</section>\n</body>|" index.html
else
  sed -i "s|</ul>|  <li><a href=\"$PAGE_URL\">$PAGE_NAME</a></li>\n</ul>|" index.html
fi

git add index.html >/dev/null 2>&1
git commit -m "🧱 Inject imported content ($PAGE_NAME)" >/dev/null 2>&1
git push >/dev/null 2>&1

echo ""
echo "✅ Import injected into $TARGET_REPO"
echo "🌐 https://$USER.github.io/$TARGET_REPO/"
echo "🧱 Cart H COMPLETE — system connected"
