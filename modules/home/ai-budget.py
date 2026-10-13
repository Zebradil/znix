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
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
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

# Extrapolating less than a day of spend turns one heavy session into a
# month-long forecast.
MIN_PROJECTION_SECONDS = 86400

BAR_WIDTH = 20
EIGHTHS = " ▏▎▍▌▋▊▉"
GREEN, YELLOW, RED, DIM, BOLD = "32", "33", "31", "2", "1"


class Unavailable(Exception):
    """A vendor can't be read for a reason the user can act on."""


@dataclass
class Row:
    vendor: str
    used: Decimal = Decimal(0)
    limit: Optional[Decimal] = None
    start: Optional[datetime] = None
    end: Optional[datetime] = None
    error: str = ""
    raw: Any = field(default=None, repr=False)


def dec(value: Any) -> Optional[Decimal]:
    """Vendor amounts can be fractional, and their docs warn off binary floats."""
    return None if value is None else Decimal(str(value))


def money(minor: Any) -> str:
    """Format a cent-equivalent amount."""
    return f"${(dec(minor) / 100).quantize(Decimal('0.01')):,}"


def pct(used: Any, limit: Any) -> Optional[float]:
    if not limit:
        return None
    return float(dec(used) / dec(limit) * 100)


def month_bounds(now: datetime) -> tuple:
    """Claude spend caps are monthly and reset at 00:00 UTC on the 1st. The
    payload states the period but not the date."""
    start = now.astimezone(timezone.utc).replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if start.month == 12:
        return start, start.replace(year=start.year + 1, month=1)
    return start, start.replace(month=start.month + 1)


def parse_utc(stamp: str) -> datetime:
    """Vendors send both `2026-11-01` and `2026-11-01T00:00:00.000Z`."""
    dt = datetime.fromisoformat(stamp)
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def projected(row: Row, now: datetime) -> Optional[Decimal]:
    """Linear run-rate: spend so far scaled to the whole period."""
    elapsed = (now - row.start).total_seconds()
    if elapsed < MIN_PROJECTION_SECONDS:
        return None
    return row.used * Decimal((row.end - row.start).total_seconds()) / Decimal(elapsed)


def pace(row: Row, now: datetime) -> float:
    """Share of the period already gone: where an even spender would be."""
    period = (row.end - row.start).total_seconds()
    return min(max((now - row.start).total_seconds() / period, 0.0), 1.0)


def amount(row: Row) -> str:
    return money(row.used) if row.limit is None else f"{money(row.used)} / {money(row.limit)}"


def _http_json(url: str, headers: dict) -> Any:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.load(resp)


def _jwt_claim(token: str, claim: str) -> Any:
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)  # base64url in a JWT carries no padding
    return json.loads(base64.urlsafe_b64decode(payload))[claim]


def dir_digest(config_dir: str) -> str:
    norm = unicodedata.normalize("NFC", config_dir)
    return hashlib.sha256(norm.encode()).hexdigest()[:8]


def keychain_service(config_dir: str) -> str:
    """Claude Code namespaces its keychain service per config dir: the bare
    name for the default dir, plus `-<sha256(dir)[:8]>` for a CLAUDE_CONFIG_DIR."""
    return f"Claude Code-credentials-{dir_digest(config_dir)}"


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
    limit = (spend.get("limit") or {}).get("amount_minor")
    start, end = month_bounds(datetime.now(timezone.utc))
    return Row("claude", dec(spend["used"]["amount_minor"]), dec(limit), start, end)


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
    try:
        start, end = parse_utc(raw["billingCycleStart"]), parse_utc(raw["billingCycleEnd"])
    except (KeyError, TypeError, ValueError):
        start, end = month_bounds(datetime.now(timezone.utc))
    return Row("cursor", dec(overall["used"]), dec(overall.get("limit")), start, end)


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
    end = parse_utc(raw.get("quota_reset_date_utc") or raw["quota_reset_date"])
    # shortcut: assumes the quota resets monthly on the 1st, as business seats
    # do; read a period start from the payload if GitHub ever ships one.
    start = month_bounds(end - timedelta(days=1))[0]
    limit = None if quota.get("unlimited") else dec(quota.get("entitlement")) or None
    return Row("copilot", dec(quota["credits_used"]), limit, start, end)


def _fresh(at: float, now: float) -> bool:
    return 0 <= now - at < CACHE_TTL


def cached(key: str, refresh: bool, fetch) -> Any:
    path = CACHE_DIR / f"{key}.json"
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
        if exc.code in (401, 403):
            return f"HTTP {exc.code} — credential may have expired"
        if exc.code == 429:
            return "HTTP 429 — rate limited, retry later"
        return f"HTTP {exc.code}"
    if isinstance(exc, urllib.error.URLError):
        return f"{exc.reason}"
    if isinstance(exc, FileNotFoundError):
        return f"missing: {exc.filename}"
    if isinstance(exc, KeyError):
        return f"unexpected response shape, no {exc}"
    return f"{type(exc).__name__}: {exc}"


def collect(name: str, key: str, fetch, to_row, refresh: bool) -> Row:
    try:
        raw = cached(key, refresh, fetch)
        row = to_row(raw)
        row.raw = raw
        return row
    except Exception as exc:  # one broken vendor must not take the tool down
        return Row(name, error=describe(exc))


def tone(share: Optional[float]) -> str:
    if share is None:
        return ""
    return RED if share >= 100 else YELLOW if share >= WARN_PCT else GREEN


def bar(share: float, mark: float, paint) -> str:
    cells = min(share, 100) / 100 * BAR_WIDTH
    full, eighth = int(cells), int(cells % 1 * 8)
    at = min(int(mark * BAR_WIDTH), BAR_WIDTH - 1)
    out = []
    for i in range(BAR_WIDTH):
        if i < full:
            out.append(paint("█", tone(share)))
        elif i == full and eighth:
            out.append(paint(EIGHTHS[eighth], tone(share)))
        elif i == at:
            out.append(paint("│", BOLD))
        else:
            out.append(paint("░", DIM))
    return "".join(out)


def render(rows: list, now: datetime, color: bool) -> None:
    def paint(text: str, code: str) -> str:
        return f"\033[{code}m{text}\033[0m" if color and code else text

    ok = [r for r in rows if not r.error]
    used_w = max((len(money(r.used)) for r in ok), default=0)
    limit_w = max((len(money(r.limit)) for r in ok if r.limit), default=0)
    projs = {r.vendor: projected(r, now) for r in ok}
    proj_w = max((len(money(p)) for p in projs.values() if p is not None), default=1)

    for r in rows:
        if r.error:
            print(f"{r.vendor:<8} {paint('unavailable: ' + r.error, DIM)}")
            continue
        share = pct(r.used, r.limit)
        proj = projs[r.vendor]
        proj_share = None if proj is None else pct(proj, r.limit)
        meter = " " * BAR_WIDTH if share is None else bar(share, pace(r, now), paint)
        share_s = "   —" if share is None else paint(f"{share:3.0f}%", tone(share))
        limit_s = f" / {money(r.limit):>{limit_w}}" if r.limit else " " * (limit_w + 3)
        proj_s = paint(f"{'—' if proj is None else money(proj):>{proj_w}}", tone(proj_share))
        proj_pct = "" if proj_share is None else paint(f" {proj_share:3.0f}%", tone(proj_share))
        left = max((r.end - now).total_seconds(), 0)
        left_s = f"{left // 86400:.0f}d" if left >= 86400 else f"{left // 3600:.0f}h"
        print(
            f"{r.vendor:<8} {meter} {share_s}  {money(r.used):>{used_w}}{limit_s}"
            f"  {paint('proj', DIM)} {proj_s}{proj_pct}"
            f"  {paint(f'resets {r.end:%Y-%m-%d} ({left_s})', DIM)}"
        )


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

    # Any non-default dir: the digest is what names the keychain entry.
    assert keychain_service("/home/user/.config/example-claude").endswith("-01e206b5")

    utc = timezone.utc
    assert month_bounds(datetime(2026, 12, 31, 23, tzinfo=utc)) == (
        datetime(2026, 12, 1, tzinfo=utc), datetime(2027, 1, 1, tzinfo=utc))
    assert parse_utc("2026-09-01") == parse_utc("2026-09-01T00:00:00.000Z")

    oct_row = Row("x", Decimal(1000), Decimal(10000),
                  datetime(2026, 10, 1, tzinfo=utc), datetime(2026, 11, 1, tzinfo=utc))
    assert projected(oct_row, datetime(2026, 10, 11, tzinfo=utc)) == Decimal(3100)
    assert projected(oct_row, datetime(2026, 10, 1, 12, tzinfo=utc)) is None
    assert pace(oct_row, datetime(2026, 9, 1, tzinfo=utc)) == 0.0

    def plain(text, _code):
        return text

    assert bar(50, 0.75, plain) == "█" * 10 + "░" * 5 + "│" + "░" * 4
    assert bar(150, 0.1, plain) == "█" * BAR_WIDTH
    assert bar(2.5, 0.0, plain) == "▌" + "░" * (BAR_WIDTH - 1)  # fill hides the marker

    assert amount(row_claude(
        {"spend": {"enabled": True, "used": {"amount_minor": 20193},
                   "limit": {"amount_minor": 50000}}}
    )) == "$201.93 / $500.00"
    cursor = row_cursor(
        {"individualUsage": {"overall": {"enabled": True, "used": 39, "limit": 30000}},
         "billingCycleStart": "2026-08-01T00:00:00.000Z",
         "billingCycleEnd": "2026-09-01T00:00:00.000Z"}
    )
    assert (cursor.start.day, cursor.end.month) == (1, 9)
    copilot = row_copilot(
        {"quota_snapshots": {"premium_interactions": {
            "has_quota": True, "credits_used": 1178, "entitlement": 40000}},
         "quota_reset_date": "2026-01-01"}
    )
    assert amount(copilot) == "$11.78 / $400.00"
    assert copilot.start == datetime(2025, 12, 1, tzinfo=utc)
    assert amount(row_copilot(
        {"quota_snapshots": {"premium_interactions": {
            "has_quota": True, "credits_used": 1178, "unlimited": True}},
         "quota_reset_date": "2026-09-01"}
    )) == "$11.78"
    print("ok")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--json", action="store_true", help="emit every field each vendor returned")
    ap.add_argument("--refresh", action="store_true", help=f"bypass the {CACHE_TTL}s cache")
    ap.add_argument(
        "--claude-config-dir",
        default=str(Path.home() / ".claude"),
        help="Claude Code profile whose spend cap to read (default: %(default)s)",
    )
    ap.add_argument("--self-check", action="store_true", help="run assertions and exit")
    args = ap.parse_args()

    if args.self_check:
        self_check()
        return 0

    claude_dir = args.claude_config_dir
    jobs = [
        # Keyed per profile so switching --claude-config-dir never shows the
        # other profile's cached spend.
        ("claude", f"claude-{dir_digest(claude_dir)}", lambda: fetch_claude(claude_dir), row_claude),
        ("cursor", "cursor", fetch_cursor, row_cursor),
        ("copilot", "copilot", fetch_copilot, row_copilot),
    ]
    with ThreadPoolExecutor(len(jobs)) as pool:
        rows = list(pool.map(lambda job: collect(*job, args.refresh), jobs))
    now = datetime.now(timezone.utc)

    if args.json:
        out = {}
        for r in rows:
            if r.error:
                out[r.vendor] = {"error": r.error}
                continue
            proj = projected(r, now)
            out[r.vendor] = {
                "amount": amount(r),
                "percent": pct(r.used, r.limit),
                "projected": None if proj is None else money(proj),
                "projected_percent": None if proj is None else pct(proj, r.limit),
                "period_start": r.start.isoformat(),
                "resets": f"{r.end:%Y-%m-%d}",
                "raw": r.raw,
            }
        print(json.dumps(out, indent=2))
    else:
        color = sys.stdout.isatty() and not os.environ.get("NO_COLOR") and os.environ.get("TERM") != "dumb"
        render(rows, now, color)
    return 0


if __name__ == "__main__":
    sys.exit(main())
