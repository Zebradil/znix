"""Month-to-date spend against the company AI caps for Claude, Cursor, Copilot.

Nothing here is configured or pasted: each vendor's own credential store is
read, so every token refreshes itself as a side effect of using the tool.

  claude   keychain entry Claude Code writes per profile dir
  cursor   the IDE's session JWT in state.vscdb
  copilot  whatever token `gh` already holds

None of the three vendors expose a member-scoped usage API. Claude and Cursor
are read through the endpoints their own UIs call, which are undocumented and
may change without notice, so a broken vendor degrades to one `unavailable`
row and never a non-zero exit.
"""

import argparse
import base64
import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
import unicodedata
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any, Optional

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "ai-budget"
CACHE_TTL = 180

# api.anthropic.com buckets callers without a claude-code User-Agent into an
# aggressively rate-limited pool that starts returning 429 within a few calls.
CLAUDE_UA = "claude-code/2.1.223"

# Alert threshold. The Claude payload carries its own `severity`, but Cursor
# and Copilot don't, so one local rule keeps the three rows comparable.
WARN_PCT = 80


class Unavailable(Exception):
    """A vendor can't be read for a reason the user can act on."""


@dataclass
class Row:
    vendor: str
    amount: str = ""
    pct: Optional[float] = None
    resets: str = ""
    error: str = ""
    raw: Any = field(default=None, repr=False)


def money(minor: Any) -> str:
    """Format a cent-equivalent amount. Vendor amounts can be fractional, and
    their docs warn off binary floats."""
    return f"${(Decimal(str(minor)) / 100).quantize(Decimal('0.01')):,}"


def pct(used: Any, limit: Any) -> Optional[float]:
    if not limit:
        return None
    return float(Decimal(str(used)) / Decimal(str(limit)) * 100)


def first_of_next_month() -> str:
    """Claude spend caps are monthly and reset at 00:00 UTC on the 1st. The
    payload states the period but not the date."""
    now = datetime.now(timezone.utc)
    year, month = (now.year + 1, 1) if now.month == 12 else (now.year, now.month + 1)
    return f"{year:04d}-{month:02d}-01"


def _http_json(url: str, headers: dict) -> Any:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.load(resp)


def _jwt_claim(token: str, claim: str) -> Any:
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)  # base64url in a JWT carries no padding
    return json.loads(base64.urlsafe_b64decode(payload))[claim]


def keychain_service(config_dir: str) -> str:
    """Claude Code namespaces its keychain service per config dir: the bare
    name for the default dir, plus `-<sha256(dir)[:8]>` for a CLAUDE_CONFIG_DIR."""
    norm = unicodedata.normalize("NFC", config_dir)
    return f"Claude Code-credentials-{hashlib.sha256(norm.encode()).hexdigest()[:8]}"


def fetch_claude(config_dir: str) -> Any:
    blob = subprocess.run(
        [
            "/usr/bin/security",
            "find-generic-password",
            "-s",
            keychain_service(config_dir),
            "-a",
            os.environ.get("USER", ""),
            "-w",
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    token = json.loads(blob)["claudeAiOauth"]["accessToken"]
    return _http_json(
        "https://api.anthropic.com/api/oauth/usage",
        {
            "Authorization": f"Bearer {token}",
            "User-Agent": CLAUDE_UA,
            "anthropic-beta": "oauth-2025-04-20",
        },
    )


def row_claude(raw: Any) -> Row:
    spend = raw.get("spend") or {}
    if not spend.get("enabled"):
        raise Unavailable("seat has no spend cap")
    used = spend["used"]["amount_minor"]
    limit = (spend.get("limit") or {}).get("amount_minor")
    amount = money(used) if limit is None else f"{money(used)} / {money(limit)}"
    return Row("claude", amount, pct(used, limit), first_of_next_month())


def fetch_cursor() -> Any:
    db = Path.home() / "Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    with tempfile.TemporaryDirectory() as tmp:
        copy = Path(tmp) / "state.vscdb"  # the running IDE holds a write lock
        shutil.copy(db, copy)
        con = sqlite3.connect(copy)
        try:
            found = con.execute(
                "select value from ItemTable where key = 'cursorAuth/accessToken'"
            ).fetchone()
        finally:
            con.close()
    if not found:
        raise Unavailable("no session in state.vscdb — sign in to Cursor")
    jwt = found[0].decode() if isinstance(found[0], bytes) else found[0]
    sub = _jwt_claim(jwt, "sub")
    return _http_json(
        "https://cursor.com/api/usage-summary",
        {"Cookie": f"WorkosCursorSessionToken={sub}%3A%3A{jwt}"},
    )


def row_cursor(raw: Any) -> Row:
    overall = ((raw.get("individualUsage") or {}).get("overall")) or {}
    if not overall.get("enabled"):
        raise Unavailable("no individual cap on this seat")
    used, limit = overall["used"], overall.get("limit")
    amount = money(used) if limit is None else f"{money(used)} / {money(limit)}"
    resets = (raw.get("billingCycleEnd") or "")[:10] or first_of_next_month()
    return Row("cursor", amount, pct(used, limit), resets)


def fetch_copilot() -> Any:
    # `gh` from PATH rather than a store path: it owns the token, and the gh
    # home module is what puts both on this machine.
    out = subprocess.run(
        ["gh", "api", "/copilot_internal/user"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return json.loads(out)


def row_copilot(raw: Any) -> Row:
    quota = (raw.get("quota_snapshots") or {}).get("premium_interactions") or {}
    if not quota.get("has_quota"):
        raise Unavailable("seat has no premium-request quota")
    used, limit = quota["credits_used"], quota.get("entitlement")
    if quota.get("unlimited") or not limit:
        return Row("copilot", money(used), None, raw.get("quota_reset_date", ""))
    amount = f"{money(used)} / {money(limit)}"
    return Row("copilot", amount, pct(used, limit), raw.get("quota_reset_date", ""))


def _fresh(at: float, now: float) -> bool:
    return 0 <= now - at < CACHE_TTL


def cached(name: str, refresh: bool, fetch) -> Any:
    path = CACHE_DIR / f"{name}.json"
    if not refresh and path.exists():
        try:
            blob = json.loads(path.read_text())
            if _fresh(blob["at"], time.time()):
                return blob["data"]
        except (json.JSONDecodeError, KeyError, OSError):
            pass  # a corrupt cache entry is just a cache miss
    data = fetch()
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"at": time.time(), "data": data}))
    return data


def describe(exc: Exception) -> str:
    if isinstance(exc, Unavailable):
        return str(exc)
    if isinstance(exc, subprocess.CalledProcessError):
        return (exc.stderr or "").strip().splitlines()[0] if exc.stderr else "command failed"
    if isinstance(exc, urllib.error.HTTPError):
        return f"HTTP {exc.code} — credential may have expired"
    if isinstance(exc, urllib.error.URLError):
        return f"{exc.reason}"
    if isinstance(exc, FileNotFoundError):
        return f"missing: {exc.filename}"
    if isinstance(exc, KeyError):
        return f"unexpected response shape, no {exc}"
    return f"{type(exc).__name__}: {exc}"


def collect(name: str, fetch, to_row, refresh: bool) -> Row:
    try:
        raw = cached(name, refresh, fetch)
        row = to_row(raw)
        row.raw = raw
        return row
    except Exception as exc:  # one broken vendor must not take the tool down
        return Row(name, error=describe(exc))


def render(rows: list) -> None:
    width = max((len(r.amount) for r in rows), default=0)
    for r in rows:
        if r.error:
            print(f"{r.vendor:<8} unavailable: {r.error}")
            continue
        share = "    —" if r.pct is None else f"{r.pct:4.0f}%"
        warn = "  !" if r.pct is not None and r.pct >= WARN_PCT else ""
        print(f"{r.vendor:<8} {r.amount:>{width}}  {share}  resets {r.resets}{warn}")


def self_check() -> None:
    assert money(20193) == "$201.93"
    assert money(50000) == "$500.00"
    assert money(0) == "$0.00"
    assert money(1234567) == "$12,345.67"
    assert money("41280.125") == "$412.80"
    assert round(pct(20193, 50000), 3) == 40.386
    assert pct(39, 30000) is not None
    assert pct(10, None) is None and pct(10, 0) is None

    body = base64.urlsafe_b64encode(b'{"sub":"auth0|user_01"}').decode().rstrip("=")
    assert _jwt_claim(f"head.{body}.sig", "sub") == "auth0|user_01"

    assert _fresh(1000.0, 1000.0) and _fresh(1000.0, 1000.0 + CACHE_TTL - 1)
    assert not _fresh(1000.0, 1000.0 + CACHE_TTL)
    assert not _fresh(1000.0, 999.0)  # clock went backwards: refetch

    # Same dir the module points at; the digest is what names the keychain entry.
    assert keychain_service("/Users/glashevich/.config/trv-claude").endswith("-ff1a770c")

    assert row_claude(
        {"spend": {"enabled": True, "used": {"amount_minor": 20193},
                   "limit": {"amount_minor": 50000}}}
    ).amount == "$201.93 / $500.00"
    assert row_cursor(
        {"individualUsage": {"overall": {"enabled": True, "used": 39, "limit": 30000}},
         "billingCycleEnd": "2026-09-01T00:00:00.000Z"}
    ).resets == "2026-09-01"
    assert row_copilot(
        {"quota_snapshots": {"premium_interactions": {
            "has_quota": True, "credits_used": 1178, "entitlement": 40000}},
         "quota_reset_date": "2026-09-01"}
    ).amount == "$11.78 / $400.00"
    assert row_copilot(
        {"quota_snapshots": {"premium_interactions": {
            "has_quota": True, "credits_used": 1178, "unlimited": True}},
         "quota_reset_date": "2026-09-01"}
    ).amount == "$11.78"
    print("ok")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--json", action="store_true", help="emit every field each vendor returned")
    ap.add_argument("--refresh", action="store_true", help=f"bypass the {CACHE_TTL}s cache")
    ap.add_argument(
        "--claude-config-dir",
        default=str(Path.home() / ".config/trv-claude"),
        help="Claude Code profile whose spend cap to read (default: %(default)s)",
    )
    ap.add_argument("--self-check", action="store_true", help="run assertions and exit")
    args = ap.parse_args()

    if args.self_check:
        self_check()
        return 0

    rows = [
        collect("claude", lambda: fetch_claude(args.claude_config_dir), row_claude, args.refresh),
        collect("cursor", fetch_cursor, row_cursor, args.refresh),
        collect("copilot", fetch_copilot, row_copilot, args.refresh),
    ]

    if args.json:
        print(json.dumps(
            {r.vendor: {"error": r.error} if r.error else
             {"amount": r.amount, "percent": r.pct, "resets": r.resets, "raw": r.raw}
             for r in rows},
            indent=2,
        ))
    else:
        render(rows)
    return 0


if __name__ == "__main__":
    sys.exit(main())
