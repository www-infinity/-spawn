#!/usr/bin/env bash
# 🧱 C13B0 — Global Ion Research Writer (UPGRADED / NO GH)
# Uses git + curl only — no gh CLI dependency
# SAFE / ADDITIVE / NON-DESTRUCTIVE

set -u

USER="${GITHUB_USER:-www-infinity}"
BASE="$HOME/c13b0_ion_research_upgraded_no_gh"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
INDEX_REPO="infinity-ion-index"

mkdir -p "$BASE"
cd "$BASE" || exit 1

DONE_LOG="$BASE/DONE.log"
FAIL_LOG="$BASE/FAIL.log"
touch "$DONE_LOG" "$FAIL_LOG"

echo "🧱 C13B0 UPGRADED Ion Sweep (NO GH) — $STAMP"

hash8() {
  if command -v sha256sum >/dev/null 2>&1; then
    echo -n "$1" | sha256sum | awk '{print $1}' | cut -c1-8
  else
    echo -n "$1" | shasum -a 256 | awk '{print $1}' | cut -c1-8
  fi
}

THEME_TITLE=(
  "Ions as the hidden currency of charge"
  "Electrochemistry: ions driving batteries and plating"
  "Ions in semiconductors: doping, defects, and drift"
  "Plasma and ionization: when gas becomes circuitry"
  "Biological ions: membranes, signals, and gradients"
  "Corrosion and passivation: ions rewriting metal"
  "Water, salts, ionic strength: conductivity and control"
  "Solid ionic transport: gels, ceramics, and sensors"
  "Ion measurement: impedance, selectivity, and fingerprints"
  "Atmospheric ions: lightning, aerosols, and charge balance"
  "Energy storage: intercalation, supercaps, and redox flow"
  "Ion selectivity: membranes, filtration, and Donnan effects"
)

THEME_FOCUS=(
  "definitions, charge neutrality, transport mechanisms, and why ions appear everywhere"
  "redox, electrode potentials, electrolyte design, plating, dendrites, and safety constraints"
  "dopants, mobile ions, oxide traps, contamination, reliability drift, and mitigation layers"
  "ionization energy, plasma sheaths, discharge control, and field-driven charge behavior"
  "Na+, K+, Ca2+, Cl− in signaling, homeostasis, gradients, and energetic cost of order"
  "galvanic couples, chloride attack, oxide films, pitting, and corrosion prevention patterns"
  "dissociation, hydration shells, activity vs concentration, ionic strength, and conductivity"
  "diffusion + migration + intercalation, solid electrolytes, and low-temperature transport"
  "EIS, conductivity, pH/ORP, ion selective probes, and practical detection logic"
  "ion creation sources, thundercloud fields, cosmic rays, aerosols, and nucleation behavior"
  "energy density vs power vs cycle life vs safety, and why ion choice is the whole game"
  "permselectivity, pore size, exclusion, boundary layers, and real purification systems"
)

API="https://api.github.com"
AUTH_HEADER=""
if [ -n "${GITHUB_TOKEN:-}" ]; then
  AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"
elif [ -n "${GH_TOKEN:-}" ]; then
  AUTH_HEADER="Authorization: token ${GH_TOKEN}"
fi

fetch_repos() {
  : > repos.list
  local page=1
  while :; do
    local url="${API}/users/${USER}/repos?per_page=100&page=${page}"
    local json
    if [ -n "$AUTH_HEADER" ]; then
      json="$(curl -fsSL -H "$AUTH_HEADER" "$url" 2>/dev/null || true)"
    else
      json="$(curl -fsSL "$url" 2>/dev/null || true)"
    fi
    [ -z "$json" ] && break
    local names
    names="$(printf "%s" "$json" | grep -oE '"name"\s*:\s*"[^"]+"' | \
      sed -E 's/.*"name"\s*:\s*"([^"]+)".*/\1/' || true)"
    [ -z "$names" ] && break
    printf "%s\n" "$names" >> repos.list
    local count
    count="$(printf "%s\n" "$names" | wc -l | tr -d ' ')"
    [ "$count" -lt 100 ] && break
    page=$((page+1))
  done
  [ -s repos.list ] && awk '!seen[$0]++' repos.list > repos.list.tmp && mv repos.list.tmp repos.list
}

if [ ! -s repos.list ]; then
  echo "🔎 Building repos.list via GitHub API (no gh)…"
  fetch_repos || true
fi

if [ ! -s repos.list ]; then
  echo "❌ Could not fetch repos. Create repos.list manually (one repo per line) in: $BASE"
  exit 1
fi

TOTAL="$(wc -l < repos.list | tr -d ' ')"
echo "📦 Repos discovered: $TOTAL"

mapfile -t REPO_ARR < repos.list
ARR_LEN="${#REPO_ARR[@]}"

pick_linked_repos() {
  local repo="$1"
  local seedhex; seedhex="$(hash8 "$repo")"
  local seeddec=$((16#${seedhex}))
  local a=$(( (seeddec + 7)  % ARR_LEN ))
  local b=$(( (seeddec + 97) % ARR_LEN ))
  local c=$(( (seeddec + 197) % ARR_LEN ))
  local r1="${REPO_ARR[$a]}" r2="${REPO_ARR[$b]}" r3="${REPO_ARR[$c]}"
  [ "$r1" = "$repo" ] && r1="${REPO_ARR[$(( (a+1)%ARR_LEN ))]}"
  [ "$r2" = "$repo" ] || [ "$r2" = "$r1" ] && r2="${REPO_ARR[$(( (b+2)%ARR_LEN ))]}"
  [ "$r3" = "$repo" ] || [ "$r3" = "$r1" ] || [ "$r3" = "$r2" ] && r3="${REPO_ARR[$(( (c+3)%ARR_LEN ))]}"
  echo "$r1" "$r2" "$r3"
}

while read -r REPO; do
  grep -qx "$REPO" "$DONE_LOG" && continue

  echo ""
  echo "🧠 Repo: $REPO"

  {
    if [ -d "$REPO" ]; then
      cd "$REPO" || exit 1
      git pull --quiet >/dev/null 2>&1 || true
    else
      git clone "https://github.com/${USER}/${REPO}.git" --quiet >/dev/null 2>&1 || exit 1
      cd "$REPO" || exit 1
    fi

    mkdir -p RESEARCH
    FILE="RESEARCH/ion_research_${REPO}.md"

    if [ -f "$FILE" ]; then
      echo "⏭️ Exists — skipping"
      cd "$BASE" || exit 1
      echo "$REPO" >> "$DONE_LOG"
      exit 0
    fi

    KEYWORDS=$(
      (echo "$REPO"; find . -maxdepth 3 -type f 2>/dev/null | sed 's|^\./||' | tr '/._-' ' ') \
      | tr ' ' '\n' | awk '!seen[$0]++' | head -n 40 | tr '\n' ', '
    )

    SEEDHEX="$(hash8 "$REPO")"
    SEEDDEC=$((16#${SEEDHEX}))
    IDX=$((SEEDDEC % ${#THEME_TITLE[@]}))
    TITLE="${THEME_TITLE[$IDX]}"
    FOCUS="${THEME_FOCUS[$IDX]}"

    read -r L1 L2 L3 < <(pick_linked_repos "$REPO")

    cat <<DOC > "$FILE"
# ⚡ Ion Research Brief — $REPO

**Generated by:** 🧱 C13B0 Global Ion Research Writer (Upgraded / No GH)
**Timestamp (UTC):** $STAMP
**Repo-anchored seed:** $SEEDHEX
**Theme:** $TITLE

---

## Theme focus: $TITLE

**Focus:** $FOCUS

**Repo keyword fingerprint:**
$KEYWORDS

---

## Ion transport modes

- **Diffusion** — driven by concentration gradients
- **Migration** — driven by electric fields
- **Convection** — carried by bulk flow

---

## Practical: measure and control

- Conductivity, pH / ORP, EIS, ion-selective probes
- Water management, surface prep, material choice

---

## Ion cluster links

- 🔗 https://github.com/$USER/$L1
- 🔗 https://github.com/$USER/$L2
- 🔗 https://github.com/$USER/$L3

---

🧱 Built to persist • Built to connect • Built to grow

— **C13B0 Ion Research Engine (Upgraded)**
DOC

    git add RESEARCH >/dev/null 2>&1 || true
    git commit -m "⚡ Add upgraded ion research (C13B0)" >/dev/null 2>&1 || true
    git push >/dev/null 2>&1 || true

    cd "$BASE" || exit 1
    echo "$REPO" >> "$DONE_LOG"
  } || {
    echo "❌ Failed: $REPO" | tee -a "$FAIL_LOG"
    cd "$BASE" >/dev/null 2>&1 || true
  }

done < repos.list

echo ""
echo "🧱 UPGRADED ION SWEEP COMPLETE"
echo "✅ Done: $(wc -l < "$DONE_LOG" | tr -d ' ')"
echo "⚠️ Failed: $(wc -l < "$FAIL_LOG" | tr -d ' ')"
