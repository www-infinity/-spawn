#!/usr/bin/env python3
"""
🧱 C13B0 Search Commit Engine
- Scrapes DuckDuckGo for real web results (no API key needed)
- Synthesizes AI response via Anthropic API, Ollama, llama.cpp, or structured fallback
- Commits each result to search_results/<id>_<slug>.md with a unique 8-char ID
- Retrieve any saved search by its ID

Usage:
  python3 search_engine/search_commit.py search <query>
  python3 search_engine/search_commit.py pull <id>
  python3 search_engine/search_commit.py list
"""

import sys
import os
import json
import uuid
import hashlib
import subprocess
import datetime
import re
import time
import html as html_module
from pathlib import Path

# ---------------------------------------------------------------------------
# Repo root: always save relative to the repo, not the script location
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent
RESULTS_DIR = REPO_ROOT / "search_results"
INDEX_PATH = RESULTS_DIR / "index.json"


# ---------------------------------------------------------------------------
# 1. DuckDuckGo scraping — no API key, two backends
# ---------------------------------------------------------------------------

def scrape_ddg(query: str, max_results: int = 8) -> list:
    """Return list of {title, url, snippet} dicts from DuckDuckGo."""
    results = _scrape_ddg_library(query, max_results)
    if not results:
        results = _scrape_ddg_html(query, max_results)
    return results


def _scrape_ddg_library(query: str, max_results: int) -> list:
    """Use ddgs (or legacy duckduckgo_search) library if available."""
    # Try new package name first, then legacy name
    ddgs_cls = None
    for mod_name, cls_name in [("ddgs", "DDGS"), ("duckduckgo_search", "DDGS")]:
        try:
            mod = __import__(mod_name, fromlist=[cls_name])
            ddgs_cls = getattr(mod, cls_name)
            break
        except (ImportError, AttributeError):
            continue

    if ddgs_cls is None:
        return []

    try:
        results = []
        with ddgs_cls() as ddgs:
            for r in ddgs.text(query, max_results=max_results):
                results.append({
                    "title": r.get("title", ""),
                    "url": r.get("href", ""),
                    "snippet": r.get("body", ""),
                })
        return results
    except Exception as exc:
        print(f"  ⚠️  DDG library: {exc}")
        return []


def _scrape_ddg_html(query: str, max_results: int) -> list:
    """Scrape DuckDuckGo HTML search page as fallback (no library needed)."""
    try:
        import urllib.request
        import urllib.parse

        q = urllib.parse.quote_plus(query)
        url = f"https://html.duckduckgo.com/html/?q={q}"
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": (
                    "Mozilla/5.0 (X11; Linux x86_64; rv:125.0) "
                    "Gecko/20100101 Firefox/125.0"
                ),
                "Accept-Language": "en-US,en;q=0.9",
            },
        )
        with urllib.request.urlopen(req, timeout=12) as resp:
            body = resp.read().decode("utf-8", errors="ignore")

        # DDG HTML result blocks
        block_re = re.compile(
            r'<div class="result[^"]*"[^>]*>(.*?)</div>\s*</div>',
            re.S,
        )
        title_re = re.compile(r'class="result__a"[^>]*>(.*?)</a>', re.S)
        url_re = re.compile(r'href="([^"]*)"[^>]*class="result__url"', re.S)
        url_text_re = re.compile(r'class="result__url"[^>]*>(.*?)</span>', re.S)
        snippet_re = re.compile(r'class="result__snippet"[^>]*>(.*?)</span>', re.S)

        results = []
        for block in block_re.findall(body):
            if len(results) >= max_results:
                break
            title_m = title_re.search(block)
            snippet_m = snippet_re.search(block)
            url_m = url_re.search(block)
            url_text_m = url_text_re.search(block)

            title = _clean(title_m.group(1)) if title_m else ""
            snippet = _clean(snippet_m.group(1)) if snippet_m else ""
            url = (
                url_m.group(1).strip()
                if url_m
                else (_clean(url_text_m.group(1)) if url_text_m else "")
            )

            if title or snippet:
                results.append({"title": title, "url": url, "snippet": snippet})

        # Second-pass fallback: simpler title/snippet extraction
        if not results:
            titles = title_re.findall(body)
            snippets = snippet_re.findall(body)
            urls = url_text_re.findall(body)
            for i in range(min(len(titles), max_results)):
                results.append({
                    "title": _clean(titles[i]),
                    "url": _clean(urls[i]) if i < len(urls) else "",
                    "snippet": _clean(snippets[i]) if i < len(snippets) else "",
                })

        return results

    except Exception as exc:
        print(f"  ⚠️  HTML scrape failed: {exc}")
        return []


def _clean(s: str) -> str:
    """Strip HTML tags and unescape HTML entities."""
    s = re.sub(r"<[^>]+>", "", s)
    return html_module.unescape(s).strip()


# ---------------------------------------------------------------------------
# 2. LLM synthesis — tries backends in order, never crashes
# ---------------------------------------------------------------------------

def synthesize(query: str, results: list) -> str:
    """Return AI-synthesized response from search results."""
    context = "\n\n".join(
        f"Result {i + 1}: {r['title']}\nURL: {r['url']}\n{r['snippet']}"
        for i, r in enumerate(results)
        if r.get("snippet") or r.get("title")
    )
    prompt = (
        f'Search query: "{query}"\n\n'
        f"Web results:\n{context}\n\n"
        "Based on these results, provide a clear, comprehensive, well-structured "
        "response to the query. Cite sources where relevant."
    )

    response = (
        _llm_anthropic(prompt)
        or _llm_ollama(prompt)
        or _llm_llamacpp(prompt)
        or _llm_fallback(query, results)
    )
    return response


def _llm_anthropic(prompt: str) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        return ""
    try:
        import urllib.request as ureq

        payload = json.dumps({
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1024,
            "messages": [{"role": "user", "content": prompt}],
        }).encode()
        req = ureq.Request(
            "https://api.anthropic.com/v1/messages",
            data=payload,
            headers={
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
        )
        with ureq.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
        return data["content"][0]["text"]
    except Exception as exc:
        print(f"  ⚠️  Anthropic: {exc}")
        return ""


def _llm_ollama(prompt: str) -> str:
    try:
        import urllib.request as ureq

        # Try to detect a running model
        model = os.environ.get("OLLAMA_MODEL", "llama3")
        payload = json.dumps({
            "model": model,
            "prompt": prompt,
            "stream": False,
        }).encode()
        req = ureq.Request(
            "http://localhost:11434/api/generate",
            data=payload,
            headers={"content-type": "application/json"},
        )
        with ureq.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
        return data.get("response", "").strip()
    except Exception:
        return ""


def _llm_llamacpp(prompt: str) -> str:
    candidates = [
        "./llama.cpp/build/bin/llama-cli",
        str(Path.home() / "llama.cpp/build/bin/llama-cli"),
        "/usr/local/bin/llama-cli",
        str(Path.home() / "llama.cpp/build/bin/main"),
    ]
    bin_path = next((p for p in candidates if Path(p).is_file()), None)
    if not bin_path:
        return ""

    model_search = [
        Path.home() / "models",
        Path("models"),
        Path("."),
    ]
    model_path = None
    for d in model_search:
        if d.is_dir():
            gguf = list(d.glob("*.gguf"))
            if gguf:
                model_path = str(sorted(gguf)[0])
                break
        elif str(d).endswith(".gguf") and Path(d).is_file():
            model_path = str(d)
            break

    if not model_path:
        return ""

    try:
        result = subprocess.run(
            [bin_path, "-m", model_path, "-p", prompt, "-n", "512",
             "--temp", "0.7", "--log-disable"],
            capture_output=True, text=True, timeout=90,
        )
        out = result.stdout.strip()
        # llama.cpp echoes the prompt — strip it
        if prompt[:40] in out:
            out = out[out.find(prompt[:40]) + len(prompt):]
        return out.strip() if out else ""
    except Exception as exc:
        print(f"  ⚠️  llama.cpp: {exc}")
        return ""


def _llm_fallback(query: str, results: list) -> str:
    """Structured summary when no LLM is available."""
    lines = [
        f"## Search Results: {query}\n",
        "_No LLM available — showing raw results. "
        "Set ANTHROPIC_API_KEY or run Ollama for AI synthesis._\n",
    ]
    for i, r in enumerate(results, 1):
        lines.append(f"**{i}. {r['title']}**")
        if r.get("url"):
            lines.append(f"🔗 {r['url']}")
        if r.get("snippet"):
            lines.append(r["snippet"])
        lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# 3. Unique ID + file management
# ---------------------------------------------------------------------------

def generate_id(query: str) -> str:
    """Return a deterministically-seeded but unique 8-hex-char ID."""
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    entropy = f"{query}:{now}:{uuid.uuid4()}"
    return hashlib.sha256(entropy.encode()).hexdigest()[:8]


def slugify(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s[:40].strip("-")


def _load_index() -> list:
    if INDEX_PATH.exists():
        try:
            return json.loads(INDEX_PATH.read_text(encoding="utf-8"))
        except Exception:
            return []
    return []


def _save_index(index: list) -> None:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    INDEX_PATH.write_text(json.dumps(index, indent=2), encoding="utf-8")


# ---------------------------------------------------------------------------
# 4. Save + commit
# ---------------------------------------------------------------------------

def save_and_commit(query: str, results: list, synthesis: str, uid: str) -> Path:
    """Write result file, update index, git add+commit+push."""
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    slug = slugify(query)
    filename = f"{uid}_{slug}.md"
    filepath = RESULTS_DIR / filename

    # Build markdown document
    raw_section = ""
    for i, r in enumerate(results, 1):
        raw_section += f"### {i}. {r['title']}\n"
        if r.get("url"):
            raw_section += f"🔗 {r['url']}\n"
        if r.get("snippet"):
            raw_section += f"{r['snippet']}\n"
        raw_section += "\n"

    content = f"""\
# 🔍 Search: {query}

| Field | Value |
|-------|-------|
| **ID** | `{uid}` |
| **Timestamp** | {timestamp} |
| **Results found** | {len(results)} |
| **Retrieve** | `python3 search_engine/search_commit.py pull {uid}` |

---

## 🤖 AI Synthesis

{synthesis}

---

## 📡 Raw DuckDuckGo Results

{raw_section}
"""
    filepath.write_text(content, encoding="utf-8")

    # Update index
    index = _load_index()
    # Remove duplicate if re-running same ID (shouldn't happen, but be safe)
    index = [e for e in index if e.get("id") != uid]
    index.insert(0, {
        "id": uid,
        "query": query,
        "file": filename,
        "timestamp": timestamp,
        "result_count": len(results),
    })
    _save_index(index)

    # Git operations (relative to repo root)
    _git_commit(uid, query)

    return filepath


def _git_commit(uid: str, query: str) -> None:
    """Stage search_results/, commit, and push."""
    try:
        subprocess.run(
            ["git", "add", "search_results/"],
            cwd=REPO_ROOT, check=True, capture_output=True,
        )
        msg = f"🔍 search [{uid}]: {query[:60]}"
        subprocess.run(
            ["git", "commit", "-m", msg],
            cwd=REPO_ROOT, check=True, capture_output=True,
        )
        print(f"✅ Committed: {msg}")

        push = subprocess.run(
            ["git", "push"],
            cwd=REPO_ROOT, capture_output=True, timeout=30,
        )
        if push.returncode == 0:
            print("✅ Pushed to remote")
        else:
            print("ℹ️  Push skipped (no remote auth — file still saved locally)")
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.decode(errors="ignore") if exc.stderr else ""
        if "nothing to commit" in stderr:
            print("ℹ️  Nothing new to commit")
        else:
            print(f"ℹ️  Git: {stderr.strip()}")


# ---------------------------------------------------------------------------
# 5. Pull by ID
# ---------------------------------------------------------------------------

def pull_by_id(uid: str) -> str:
    """Return the full content of a saved search by its ID (prefix match)."""
    index = _load_index()
    if not index:
        return "❌ No saved searches yet. Run: search_commit.py search <query>"

    matches = [e for e in index if e["id"].startswith(uid)]
    if not matches:
        return (
            f"❌ No result found for ID: '{uid}'\n"
            f"   Run 'python3 search_engine/search_commit.py list' to see all IDs."
        )

    if len(matches) > 1:
        lines = [f"⚠️  Multiple matches for '{uid}':"]
        for m in matches:
            lines.append(f"  [{m['id']}] {m['query']} — {m['timestamp']}")
        lines.append("Provide more characters to disambiguate.")
        return "\n".join(lines)

    entry = matches[0]
    filepath = RESULTS_DIR / entry["file"]

    # Try to pull latest from remote first
    subprocess.run(
        ["git", "pull", "--quiet"],
        cwd=REPO_ROOT, capture_output=True,
    )

    if not filepath.exists():
        return f"❌ File not found locally: {filepath}\n   It may exist on remote — check git pull."

    return filepath.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# 6. List saved searches
# ---------------------------------------------------------------------------

def list_searches() -> str:
    index = _load_index()
    if not index:
        return "📭 No saved searches yet.\n   Run: python3 search_engine/search_commit.py search <query>"

    lines = [f"📚 Saved searches ({len(index)} total):\n"]
    for entry in index[:30]:
        lines.append(
            f"  [{entry['id']}]  {entry['query']:<45}  "
            f"{entry['result_count']} results  {entry['timestamp']}"
        )
    if len(index) > 30:
        lines.append(f"\n  … and {len(index) - 30} more (see search_results/index.json)")
    lines.append("\nRetrieve with:  python3 search_engine/search_commit.py pull <id>")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# 7. CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print(__doc__)
        sys.exit(0)

    cmd = sys.argv[1]

    if cmd == "search":
        if len(sys.argv) < 3:
            print("❌  Usage: python3 search_engine/search_commit.py search <query>")
            sys.exit(1)

        query = " ".join(sys.argv[2:])
        print(f"\n🔍  Searching DuckDuckGo: «{query}»")

        print("📡  Scraping results…")
        results = scrape_ddg(query, max_results=8)
        print(f"    Found {len(results)} results")

        if not results:
            print("⚠️   No results — check internet connection or try a different query.")
            sys.exit(1)

        print("🤖  Synthesizing with AI…")
        synthesis = synthesize(query, results)

        uid = generate_id(query)
        print(f"🔑  Unique ID: {uid}")

        filepath = save_and_commit(query, results, synthesis, uid)

        print(f"\n✅  Saved: {filepath.relative_to(REPO_ROOT)}")
        print(f"🔑  Retrieve later:  python3 search_engine/search_commit.py pull {uid}\n")
        print("─" * 60)
        preview = synthesis[:800]
        print(preview + ("\n…[truncated — see file for full response]" if len(synthesis) > 800 else ""))
        print("─" * 60)

    elif cmd == "pull":
        if len(sys.argv) < 3:
            print("❌  Usage: python3 search_engine/search_commit.py pull <id>")
            sys.exit(1)
        print(pull_by_id(sys.argv[2]))

    elif cmd == "list":
        print(list_searches())

    else:
        print(f"❌  Unknown command: '{cmd}'")
        print("    Commands: search | pull | list | help")
        sys.exit(1)


if __name__ == "__main__":
    main()
