#!/usr/bin/env bash
# 🧱 C13B0 — Search, Synthesize & Commit
# Scrapes DuckDuckGo for real results, synthesizes with AI (Anthropic / Ollama /
# llama.cpp), commits to search_results/ with a unique 8-char ID.
#
# Usage:
#   ./cart_search_commit.sh search <query>   — search + AI response + commit
#   ./cart_search_commit.sh pull  <id>       — retrieve saved search by ID
#   ./cart_search_commit.sh list             — list all saved searches
#   ./cart_search_commit.sh install          — install Python deps
#
# LLM priority (first available wins):
#   1. ANTHROPIC_API_KEY env var  → Claude Haiku (fast, accurate)
#   2. Ollama running locally     → any model (OLLAMA_MODEL, default llama3)
#   3. llama.cpp binary + .gguf   → local inference
#   4. Structured summary fallback (always works, no LLM)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEARCH_PY="$SCRIPT_DIR/search_engine/search_commit.py"

CMD="${1:-help}"
shift || true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
install_deps() {
  echo "📦 Installing Python dependencies…"
  if command -v pip3 &>/dev/null; then
    pip3 install ddgs requests beautifulsoup4 \
      --break-system-packages -q 2>/dev/null \
      || pip3 install ddgs requests beautifulsoup4 -q
  elif command -v pip &>/dev/null; then
    pip install ddgs requests beautifulsoup4 -q
  else
    echo "⚠️  pip not found. Install Python 3 and pip first."
    return 1
  fi
  echo "✅ Dependencies installed"
}

ensure_python() {
  if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
    echo "❌ Python 3 is required. Install with: pkg install python (Termux) or apt install python3"
    exit 1
  fi
}

run_py() {
  if command -v python3 &>/dev/null; then
    python3 "$SEARCH_PY" "$@"
  else
    python "$SEARCH_PY" "$@"
  fi
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
case "$CMD" in

  search)
    ensure_python
    if [ -z "${*:-}" ]; then
      echo "❌  Usage: ./cart_search_commit.sh search <query>"
      echo "    Example: ./cart_search_commit.sh search 'aluminum oxide quantum computing'"
      exit 1
    fi

    # Auto-install ddgs silently if missing
    if ! python3 -c "import ddgs" 2>/dev/null && \
       ! python3 -c "import duckduckgo_search" 2>/dev/null; then
      echo "📦 Installing ddgs (first run)…"
      pip3 install ddgs --break-system-packages -q 2>/dev/null \
        || pip3 install ddgs -q 2>/dev/null || true
    fi

    run_py search "$@"
    ;;

  pull)
    ensure_python
    if [ -z "${1:-}" ]; then
      echo "❌  Usage: ./cart_search_commit.sh pull <id>"
      echo "    Example: ./cart_search_commit.sh pull a1b2c3d4"
      exit 1
    fi
    run_py pull "$1"
    ;;

  list)
    ensure_python
    run_py list
    ;;

  install)
    install_deps
    ;;

  demo)
    # Quick smoke-test with a safe query (no AI needed)
    ensure_python
    echo "🧪 Demo search (structured fallback — no AI required)…"
    run_py search "infinity crown index github pages"
    ;;

  help|--help|-h|*)
    cat <<'HELP'
🧱 C13B0 Search Commit Engine
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

USAGE
  ./cart_search_commit.sh <command> [args]

COMMANDS
  search <query>   Scrape DuckDuckGo, synthesize with AI, commit to repo
  pull   <id>      Retrieve a saved search result by its unique 8-char ID
  list             List all saved searches with their IDs and timestamps
  install          Install Python deps (duckduckgo-search, requests, bs4)
  demo             Run a quick test search (no AI key needed)

EXAMPLES
  ./cart_search_commit.sh search "helium-3 lunar mining 2026"
  ./cart_search_commit.sh pull a1b2c3d4
  ./cart_search_commit.sh list

AI BACKENDS (tried in order)
  1. Anthropic Claude  →  export ANTHROPIC_API_KEY=sk-ant-...
  2. Ollama (local)    →  ollama serve + export OLLAMA_MODEL=llama3
  3. llama.cpp         →  ~/llama.cpp/build/bin/llama-cli + *.gguf in ~/models/
  4. Structured summary (always works — no LLM required)

FILES
  search_results/<id>_<slug>.md   — full result per search
  search_results/index.json       — searchable index of all saves

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HELP
    ;;
esac
