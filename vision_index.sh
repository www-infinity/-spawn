#!/usr/bin/env bash
# 🧱 C13B0 — Index & Vision Repo Generator
# SAFE MODE: indexing, search, pages only
# NO wallets, NO mining, NO markets

set -euo pipefail

USER="${GITHUB_USER:-www-infinity}"
PREFIX="vision-index"
STAMP=$(date -u +%Y%m%d_%H%M%S)
REPO="${PREFIX}-${STAMP}"

echo "🧱 Creating repo: $REPO"

# ----------------------------
# 1. CREATE + CLONE REPO
# ----------------------------

gh repo create "$USER/$REPO" --public --confirm
git clone "https://github.com/$USER/$REPO.git"
cd "$REPO"
git checkout -b main

# ----------------------------
# 2. CONTENT TO INDEX
# ----------------------------

mkdir -p content index

cat <<EOF > content/welcome.md
# Infinity Vision Index

This repo is a machine.
Every run creates a new instance.
No data is deleted.

Generated: $(date -u)
EOF

# ----------------------------
# 3. BUILD SEARCH INDEX
# ----------------------------

INDEX_FILE="index/search.json"
echo "[]" > "$INDEX_FILE"

while IFS= read -r file; do
  TITLE=$(head -n 1 "$file" | sed 's/# //')
  BODY=$(tail -n +2 "$file" | tr '\n' ' ' | sed "s/\"/''/g")

  jq --arg t "$TITLE" \
     --arg b "$BODY" \
     --arg p "$file" \
     '. += [{title:$t, body:$b, path:$p}]' \
     "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"

done < <(find content -type f -name "*.md")

# ----------------------------
# 4. STATIC SITE (SEARCH UI)
# ----------------------------

cat <<'HTML' > index.html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Infinity Vision Index</title>
<style>
body { font-family: system-ui; background:#0b1220; color:#e5e7eb; padding:20px }
h1 { margin:0 0 12px }
input { width:100%; padding:10px; font-size:16px; background:#111827; color:#e5e7eb; border:1px solid #374151; border-radius:8px; outline:none }
.result { margin-top:15px; padding:12px; background:#111827; border-radius:8px; border:1px solid #374151 }
.result b { color:#60a5fa }
</style>
</head>
<body>
<h1>∞ Infinity Vision Index</h1>
<p style="color:#9ca3af">This is a machine. Each repo is one cycle.</p>
<input id="q" placeholder="Search the machine..." oninput="search()" />
<div id="results"></div>
<script>
let data = [];
fetch('index/search.json').then(r => r.json()).then(j => { data = j; });
function search() {
  const q = document.getElementById('q').value.toLowerCase();
  const r = document.getElementById('results');
  r.innerHTML = '';
  if (!q) return;
  data.filter(x => x.body.toLowerCase().includes(q) || x.title.toLowerCase().includes(q))
    .forEach(x => {
      const d = document.createElement('div');
      d.className = 'result';
      d.innerHTML = '<b>' + x.title + '</b><br>' + x.body.slice(0, 200);
      r.appendChild(d);
    });
}
</script>
</body>
</html>
HTML

# ----------------------------
# 5. ENABLE PAGES
# ----------------------------

git add .
git commit -m "🧱 C13B0: vision index machine"
git push origin main

gh api -X POST \
  "repos/$USER/$REPO/pages" \
  -f source.branch=main \
  -f source.path=/ || true

echo "✅ Repo created: $REPO"
echo "🌐 Pages will be live shortly at:"
echo "   https://$USER.github.io/$REPO/"
