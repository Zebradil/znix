#!/usr/bin/env python3
"""Export a Claude Code, Cursor, or opencode session transcript as readable Markdown or JSON.

Three stores, one projection. Claude Code appends a JSONL event log per session;
Cursor writes a slimmer JSONL under `~/.cursor/projects/*/agent-transcripts/`;
opencode writes rows into SQLite (`session` / `message` / `part`). All three
are reduced to the same event list, so every renderer below is source-agnostic.

A "chat" is a projection over that log, not a message list: assistant prose
lives in text blocks, but the substance of a driven session often lives in a
question payload (the options, the answer, the notes recorded beside it), so
scraping prose alone yields almost nothing.
"""

import argparse
import json
import os
import re
import shlex
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path

TOOL_INPUT_CHARS = 120
RESULT_LINES = 20
RESULT_CHARS = 2048

# Always on: an export exists to leave this machine, and a redactor behind a
# flag is one you forget on the day it matters. Prefixes only — near-zero
# false-positive rate, no entropy heuristics to tune.
REDACTIONS = [
    re.compile(r"sk-ant-[A-Za-z0-9_-]{8,}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{16,}"),
    re.compile(r"github_pat_[A-Za-z0-9_]{20,}"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"),
    re.compile(r"AGE-SECRET-KEY-[A-Z0-9]{20,}"),
    re.compile(
        r"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----"
    ),
]


def redact(text):
    if not text:
        return text
    for pattern in REDACTIONS:
        text = pattern.sub("[REDACTED]", text)
    return text


def distinct(values):
    seen = []
    for value in values:
        if value and value not in seen:
            seen.append(value)
    return seen


# --- locating sessions ------------------------------------------------------


def claude_ref(path):
    return {"tool": "claude", "path": Path(path)}


def cursor_ref(path):
    return {"tool": "cursor", "path": Path(path)}


def opencode_ref(db, session_id):
    return {"tool": "opencode", "db": Path(db), "id": session_id}


def project_roots():
    """Every Claude config dir on this machine, not just the active one.

    A profile is just a config dir (`~/.config/personal-claude`, `trv-claude`,
    …), and `CLAUDE_CONFIG_DIR` names only whichever one is running. Outside a
    session it is unset, so relying on it alone hides every profile's history.
    """
    roots = []
    env = os.environ.get("CLAUDE_CONFIG_DIR")
    if env:
        roots.append(Path(env) / "projects")
    roots.append(Path.home() / ".claude" / "projects")
    roots += sorted((Path.home() / ".config").glob("*claude*/projects"))
    return [r for r in dict.fromkeys(roots) if r.is_dir()]


def profile_name(path):
    """Which profile a transcript belongs to: <config-dir>/projects/<project>/x.jsonl."""
    return path.parent.parent.parent.name.lstrip(".") or "claude"


def mangle(path):
    """Claude Code's project dir name: every non-alphanumeric run becomes a dash.

    Not just the slashes — `github.com/a_b` lands as `github-com-a-b`, so a
    slash-only substitution matches nothing for any checkout with a dot in it.
    """
    return re.sub(r"[^A-Za-z0-9]", "-", str(path))


def cursor_project_name(path):
    """Cursor's project dir: same dash-mangle, but the leading slash is dropped.

    `/Users/me/code/github.com/o/a_b` → `Users-me-code-github-com-o-a-b`, sitting
    at `~/.cursor/projects/<name>/`. Claude keeps the leading dash.
    """
    return mangle(path).lstrip("-")


def project_label(mangled):
    """A project's mangled dir name, shortened against $HOME so the distinctive
    tail fits a column: `-Users-me-code-github-com-o-repo` -> `code-github-com-o-repo`.

    Cursor dirs drop the leading dash Claude keeps; prepend it so the same
    home-prefix trim applies.
    """
    if mangled and not mangled.startswith("-"):
        mangled = "-" + mangled
    home = mangle(Path.home())
    trimmed = mangled[len(home) :] if mangled.startswith(home) else mangled
    return trimmed.strip("-") or mangled.strip("-")


def column(text, width):
    """Left-truncated so the tail — the part that identifies a project — survives."""
    return (text if len(text) <= width else "\u2026" + text[-(width - 1) :]).ljust(width)


def project_dirs_for_cwd():
    """One per profile that has seen this directory — all of them, not the first."""
    mangled = mangle(Path.cwd())
    return [root / mangled for root in project_roots() if (root / mangled).is_dir()]


def session_files(scope=None):
    dirs = (
        scope
        if scope is not None
        else [d for r in project_roots() for d in r.iterdir() if d.is_dir()]
    )
    files = [f for d in dirs for f in d.glob("*.jsonl")]
    return sorted(files, key=lambda f: f.stat().st_mtime, reverse=True)


def cursor_projects_root():
    return Path.home() / ".cursor" / "projects"


def cursor_project_dirs(scoped):
    """Cursor's per-workspace folders, or just the one for cwd when scoped."""
    root = cursor_projects_root()
    if not root.is_dir():
        return []
    if scoped:
        found = root / cursor_project_name(Path.cwd())
        return [found] if found.is_dir() else []
    return [d for d in root.iterdir() if d.is_dir()]


def cursor_session_files(dirs):
    files = [f for d in dirs for f in (d / "agent-transcripts").glob("*/*.jsonl")]
    return sorted(files, key=lambda f: f.stat().st_mtime, reverse=True)


CURSOR_QUERY_RE = re.compile(r"<user_query>\s*(.*?)</user_query>", re.S)
CURSOR_SKILLS_RE = re.compile(
    r"<manually_attached_skills>.*?</manually_attached_skills>", re.S
)
CURSOR_CLOCK_RE = re.compile(
    r"<timestamp>\s*(?P<body>.*?)\s*</timestamp>",
    re.S,
)
CURSOR_CLOCK_BODY = re.compile(
    r"(?P<mon>[A-Za-z]+) (?P<day>\d{1,2}), (?P<year>\d{4}), "
    r"(?P<hour>\d{1,2}):(?P<minute>\d{2}) (?P<ampm>AM|PM) "
    r"\(UTC(?:(?P<off>[+-]\d{1,2}(?::\d{2})?))?\)$",
    re.I,
)
_MONTHS = {
    "jan": 1,
    "feb": 2,
    "mar": 3,
    "apr": 4,
    "may": 5,
    "jun": 6,
    "jul": 7,
    "aug": 8,
    "sep": 9,
    "oct": 10,
    "nov": 11,
    "dec": 12,
}


def iso_mtime(path):
    return (
        datetime.fromtimestamp(path.stat().st_mtime, timezone.utc)
        .isoformat(timespec="seconds")
        .replace("+00:00", "Z")
    )


def cursor_clock_to_iso(raw):
    """`Friday, Sep 11, 2026, 12:20 AM (UTC+2)` → UTC ISO. None if it doesn't parse."""
    raw = " ".join((raw or "").split())
    # Weekday is prefix noise; the body starts at the month.
    chopped = raw.split(", ", 1)[-1] if ", " in raw else raw
    parsed = CURSOR_CLOCK_BODY.search(chopped) or CURSOR_CLOCK_BODY.search(raw)
    if not parsed:
        return None
    month = _MONTHS.get(parsed.group("mon")[:3].lower())
    if not month:
        return None
    hour = int(parsed.group("hour"))
    if parsed.group("ampm").upper() == "AM":
        hour = 0 if hour == 12 else hour
    else:
        hour = hour if hour == 12 else hour + 12
    local = datetime(
        int(parsed.group("year")),
        month,
        int(parsed.group("day")),
        hour,
        int(parsed.group("minute")),
    )
    off = parsed.group("off")
    if off:
        sign = 1 if off[0] == "+" else -1
        bits = off[1:].split(":")
        minutes = sign * (int(bits[0]) * 60 + (int(bits[1]) if len(bits) > 1 else 0))
    else:
        minutes = 0
    utc = local.replace(tzinfo=timezone.utc) - timedelta(minutes=minutes)
    return utc.isoformat(timespec="seconds").replace("+00:00", "Z")


def cursor_plain_content(record):
    content = record.get("message", {}).get("content")
    if isinstance(content, list):
        return "\n".join(
            b.get("text") or ""
            for b in content
            if isinstance(b, dict) and b.get("type") == "text"
        )
    return content if isinstance(content, str) else ""


def cursor_user_text(record):
    """The prompt, with Cursor's wrapper tags stripped.

    User turns arrive as `<timestamp>…</timestamp><user_query>…</user_query>`,
    sometimes with a `<manually_attached_skills>` blob. The query is the
    message; the timestamp becomes the event's `ts`.
    """
    if record.get("role") != "user":
        return ""
    text = CURSOR_SKILLS_RE.sub("", cursor_plain_content(record))
    found = CURSOR_QUERY_RE.search(text)
    if found:
        return found.group(1).strip()
    text = CURSOR_CLOCK_RE.sub("", text).strip()
    return text


def cursor_record_ts(record):
    found = CURSOR_CLOCK_RE.search(cursor_plain_content(record))
    return cursor_clock_to_iso(found.group("body")) if found else None


def opencode_dbs():
    """One database per release channel: opencode-stable.db, -dev, and friends."""
    root = (
        Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
        / "opencode"
    )
    return sorted(root.glob("opencode*.db"))


def connect(db):
    """Read-only, and deliberately not `immutable=1`.

    opencode may be running: an immutable open skips the -wal file and would
    silently serve a transcript missing everything since the last checkpoint.
    """
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=2)
    conn.row_factory = sqlite3.Row
    return conn


def summarize(path):
    """Cheap one-line summary for --list and the picker."""
    title = ""
    with path.open() as handle:
        for line in handle:
            if '"ai-title"' in line:
                try:
                    title = json.loads(line).get("aiTitle") or title
                except json.JSONDecodeError:
                    pass
    when = datetime.fromtimestamp(path.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
    size = path.stat().st_size // 1024
    return path.stem, when, f"{size}K", title


def cursor_summarize(path):
    """Same columns as summarize(), title from the first user_query."""
    title = ""
    with path.open() as handle:
        for line in handle:
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            text = cursor_user_text(rec)
            if text:
                title = text.splitlines()[0]
                break
    when = datetime.fromtimestamp(path.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
    size = path.stat().st_size // 1024
    return path.stem, when, f"{size}K", redact(title)


def rows(scoped):
    """Every tool's sessions as picker rows, newest first."""
    found = []

    scope = project_dirs_for_cwd() if scoped else None
    if scope or not scoped:
        for path in session_files(scope):
            sid, when, size, title = summarize(path)
            found.append(
                {
                    "tool": "claude",
                    "label": profile_name(path),
                    "project": project_label(path.parent.name),
                    "id": sid,
                    "when": when,
                    "size": size,
                    "title": title,
                    "ref": claude_ref(path),
                    "sort": path.stat().st_mtime,
                }
            )

    cwd = str(Path.cwd())
    for db in opencode_dbs():
        # Child sessions are subagent runs; their substance already rides on the
        # parent's `task` call, so they are not offered as separate transcripts.
        query = (
            "select id, title, time_updated, directory from session "
            "where parent_id is null"
        )
        if scoped:
            query += " and directory = ?"
        with closing(connect(db)) as conn:
            for row in conn.execute(query, (cwd,) if scoped else ()):
                found.append(
                    {
                        "tool": "opencode",
                        "label": "opencode",
                        "project": project_label(mangle(row["directory"])),
                        "id": row["id"],
                        "when": datetime.fromtimestamp(
                            row["time_updated"] / 1000
                        ).strftime("%Y-%m-%d %H:%M"),
                        "size": "—",
                        "title": row["title"] or "",
                        "ref": opencode_ref(db, row["id"]),
                        "sort": row["time_updated"] / 1000,
                    }
                )

    for path in cursor_session_files(cursor_project_dirs(scoped)):
        sid, when, size, title = cursor_summarize(path)
        found.append(
            {
                "tool": "cursor",
                "label": "cursor",
                "project": project_label(path.parent.parent.parent.name),
                "id": sid,
                "when": when,
                "size": size,
                "title": title,
                "ref": cursor_ref(path),
                "sort": path.stat().st_mtime,
            }
        )

    return sorted(found, key=lambda r: r["sort"], reverse=True)


def scoped_rows(everywhere=False):
    """This project's sessions, falling back to every project when it has none."""
    if everywhere:
        return rows(False)
    return rows(True) or rows(False)


def jsonl_ref(path):
    """A .jsonl path is Claude or Cursor; the directory is the reliable signal."""
    path = Path(path)
    if "agent-transcripts" in path.parts:
        return cursor_ref(path)
    try:
        with path.open() as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                rec = json.loads(line)
                if rec.get("type") == "turn_ended" or (
                    rec.get("role") in ("user", "assistant") and "type" not in rec
                ):
                    return cursor_ref(path)
                return claude_ref(path)
    except (OSError, json.JSONDecodeError):
        pass
    return claude_ref(path)


def resolve(arg, everywhere=False):
    """A path, or a bare session id looked up in any store."""
    if not arg:
        return pick(everywhere)

    candidate = Path(arg)
    if candidate.is_file():
        return jsonl_ref(candidate)
    for root in project_roots():
        hits = sorted(root.glob(f"*/{arg}*.jsonl"))
        if hits:
            return claude_ref(hits[0])
    hits = cursor_session_files(cursor_project_dirs(False))
    for path in hits:
        if path.stem.startswith(arg):
            return cursor_ref(path)
    for db in opencode_dbs():
        with closing(connect(db)) as conn:
            hit = conn.execute(
                "select id from session where id like ? order by time_updated desc limit 1",
                (arg + "%",),
            ).fetchone()
        if hit:
            return opencode_ref(db, hit["id"])

    searched = (
        [str(r) for r in project_roots()]
        + [str(cursor_projects_root())]
        + [str(d) for d in opencode_dbs()]
    )
    sys.exit(f"no session matching {arg!r} under {searched}")


def list_sessions(everywhere=False):
    for row in scoped_rows(everywhere):
        where = f"{column(row['project'], 34)}  " if everywhere else ""
        print(
            f"{row['label']:15}  {where}{row['id'][:12]}  {row['when']}  {row['size']:>6}  {row['title']}"
        )


def preview_command():
    """fzf renders the highlighted row by re-invoking this script on its ref."""
    cmd = (
        f"{shlex.quote(sys.executable)} "
        f"{shlex.quote(str(Path(__file__).resolve()))} --preview {{2}}"
    )
    if shutil.which("bat"):
        cmd += " | bat --language=markdown --color=always --style=plain"
    return cmd


def preview(payload):
    """Render one row for the fzf preview pane; never let a bad ref kill fzf."""
    try:
        ref = json.loads(payload)
        for key in ("path", "db"):
            if key in ref:
                ref[key] = Path(ref[key])
        return export(ref, "brief", "table", False)
    # SystemExit too: opencode_load exits on a missing session.
    except (Exception, SystemExit) as err:  # noqa: BLE001 - the pane shows the reason instead
        return f"preview failed: {err}\n"


def pick(everywhere=False, multi=False):
    """One session's ref, or with `multi` every chosen row (Tab marks several)."""
    if not shutil.which("fzf"):
        sys.exit(
            "no session given and fzf is not installed — pass a path or session id"
        )
    found = scoped_rows(everywhere)
    lines = [
        f"{i}\t{json.dumps(row['ref'], default=str)}\t{row['label']:15}  "
        f"{column(row['project'], 34) + '  ' if everywhere else ''}"
        f"{row['when']}  {row['size']:>6}  {row['title']}"
        for i, row in enumerate(found)
    ]
    chosen = subprocess.run(
        ["fzf", "--with-nth=3..", "--delimiter=\t",
         "--prompt=delete> " if multi else "--prompt=session> ",
         *(["--multi"] if multi else []),
         f"--preview={preview_command()}", "--preview-window=bottom,70%,wrap"],
        input="\n".join(lines),
        capture_output=True,
        text=True,
    )
    if chosen.returncode != 0 or not chosen.stdout.strip():
        sys.exit("no session selected")
    picked = [found[int(line.split("\t", 1)[0])] for line in chosen.stdout.splitlines()]
    return picked if multi else picked[0]["ref"]


# --- deleting ---------------------------------------------------------------


def config_dir(path):
    """<config-dir>/projects/<project>/<id>.jsonl -> <config-dir>."""
    return path.parent.parent.parent


def session_paths(ref):
    """Everything on disk a session owns; opencode rows go through its CLI instead.

    Claude spreads one session over the transcript, a sibling `<id>/` dir
    (subagents, tool-results), `file-history/<id>` and `session-env/<id>`. The
    shared `history.jsonl` is left alone: live sessions append to it.
    """
    if ref["tool"] == "cursor":
        return [ref["path"].parent]
    if ref["tool"] != "claude":
        return []
    path, root = ref["path"], config_dir(ref["path"])
    candidates = [
        path,
        path.with_suffix(""),
        root / "file-history" / path.stem,
        root / "session-env" / path.stem,
    ]
    return [p for p in candidates if p.exists()]


def live_ids():
    """Session ids of running Claude processes, from <config-dir>/sessions/<pid>.json."""
    ids = set()
    for root in project_roots():
        for entry in (root.parent / "sessions").glob("*.json"):
            try:
                info = json.loads(entry.read_text())
                os.kill(int(info["pid"]), 0)
            except (OSError, ValueError, KeyError, TypeError):
                continue
            ids.add(info.get("sessionId"))
    return ids


def disk_size(path):
    if path.is_file():
        return path.stat().st_size
    return sum(f.stat().st_size for f in path.rglob("*") if f.is_file())


def remove(path):
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    else:
        path.unlink()


def paint(text, *codes):
    """ANSI styling for the confirmation screen, off when stderr isn't a terminal."""
    if not codes or os.environ.get("NO_COLOR") or not sys.stderr.isatty():
        return text
    return f"\033[{';'.join(codes)}m{text}\033[0m"


BOLD, DIM, RED, GREEN, YELLOW, CYAN = "1", "2", "31", "32", "33", "36"


def human_size(size):
    for unit in ("B", "K", "M"):
        if size < 1024:
            return f"{size:.0f}{unit}" if unit == "B" else f"{size:.1f}{unit}"
        size /= 1024
    return f"{size:.1f}G"


def home_relative(path):
    home = str(Path.home())
    text = str(path)
    return "~" + text[len(home) :] if text.startswith(home + os.sep) else text


def rule(title, *codes, width=72):
    head = f"── {title} "
    return paint(head, *codes) + paint("─" * max(width - len(head), 4), DIM)


def confirmation_block(row, paths, sizes):
    """One session: title, a dim facts line, then what goes away."""
    lines = [f"  {paint('●', RED)} {paint(row['title'] or '(untitled)', BOLD)}"]
    facts = [
        f"id {row['id']}",
        f"updated {row['when']}",
        f"size {row['size']}",
    ]
    lines.append("    " + paint("   ".join(facts), DIM))
    if row["ref"]["tool"] == "opencode":
        lines.append(f"    {paint('run', YELLOW)} opencode session delete {row['id']}")
    for path, size in zip(paths, sizes):
        lines.append(
            f"    {paint('rm ', RED)} {home_relative(path)}{'/' if path.is_dir() else ''}"
            f"  {paint(human_size(size), DIM)}"
        )
    return "\n".join(lines)


def delete_sessions(everywhere=False):
    running = live_ids()
    doomed, skipped, total = [], [], 0
    sections = {}
    for row in pick(everywhere, multi=True):
        if row["id"] in running:
            skipped.append(row)
            continue
        paths = session_paths(row["ref"])
        sizes = [disk_size(path) for path in paths]
        total += sum(sizes)
        doomed.append((row, paths))
        title = f"{row['label']} · {row['project']}"
        sections.setdefault(title, []).append(confirmation_block(row, paths, sizes))

    out = sys.stderr
    print(file=out)
    for title, blocks in sections.items():
        print(rule(title, BOLD, CYAN), file=out)
        print("\n\n".join(blocks), file=out)
        print(file=out)
    if skipped:
        print(rule("Skipped: still running", BOLD, YELLOW), file=out)
        for row in skipped:
            print(f"  {paint('○', YELLOW)} {row['title'] or '(untitled)'}", file=out)
            print("    " + paint(f"{row['label']} · {row['project']} · id {row['id']}", DIM), file=out)
        print(file=out)

    if not doomed:
        sys.exit("nothing to delete")
    summary = f"{plural(len(doomed), 'session')}, {human_size(total)} on disk"
    print(rule("Summary", BOLD), file=out)
    print(f"  {summary}. This cannot be undone.\n", file=out)
    with open("/dev/tty") as tty:
        print(paint(f"Delete {plural(len(doomed), 'session')}? [y/N] ", BOLD, RED), end="", file=out, flush=True)
        if tty.readline().strip().lower() not in ("y", "yes"):
            sys.exit("aborted")

    failed = 0
    for row, paths in doomed:
        try:
            if row["ref"]["tool"] == "opencode":
                if not shutil.which("opencode"):
                    raise RuntimeError("opencode CLI not on PATH")
                subprocess.run(["opencode", "session", "delete", row["id"]], check=True)
            for path in paths:
                remove(path)
            print(f"{paint('deleted', GREEN)} {row['label']} {row['id']}  {row['title']}")
        except (OSError, RuntimeError, subprocess.CalledProcessError) as err:
            failed += 1
            print(f"{paint('FAILED', BOLD, RED)} {row['label']} {row['id']}: {err}", file=sys.stderr)
    if failed:
        sys.exit(f"{plural(failed, 'session')} not deleted")


# --- parsing: Claude Code ---------------------------------------------------


def load(path):
    records = []
    with path.open() as handle:
        for line in handle:
            line = line.strip()
            if line:
                try:
                    records.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    return records


def blocks(record, kind):
    content = record.get("message", {}).get("content")
    if isinstance(content, list):
        return [b for b in content if b.get("type") == kind]
    return []


def build_meta(records, path):
    stamps = sorted(r["timestamp"] for r in records if r.get("timestamp"))
    tools = {}
    out_tokens = cache_tokens = 0
    for record in records:
        if record.get("type") == "assistant":
            usage = record.get("message", {}).get("usage") or {}
            out_tokens += usage.get("output_tokens", 0)
            cache_tokens += usage.get("cache_read_input_tokens", 0)
            for block in blocks(record, "tool_use"):
                tools[block["name"]] = tools.get(block["name"], 0) + 1

    prompts = sum(
        1
        for r in records
        if r.get("type") == "user"
        and not r.get("isMeta")
        and isinstance(r.get("message", {}).get("content"), str)
        and not r["message"]["content"].startswith(("<command-name>", "<local-command"))
    )
    return {
        "tool": "claude",
        "title": (
            [r.get("aiTitle") for r in records if r.get("type") == "ai-title"] or [None]
        )[-1],
        "session_id": next(
            (r["sessionId"] for r in records if r.get("sessionId")), None
        ),
        "path": str(path),
        "profile": profile_name(path),
        "started": stamps[0] if stamps else None,
        "ended": stamps[-1] if stamps else None,
        "cwd": next((r["cwd"] for r in records if r.get("cwd")), None),
        "git_branch": next(
            (r["gitBranch"] for r in records if r.get("gitBranch")), None
        ),
        "models": distinct(r.get("message", {}).get("model") for r in records),
        "efforts": distinct(r.get("effort") for r in records),
        "client_version": distinct(r.get("version") for r in records),
        "modes": distinct(r.get("mode") for r in records),
        "permission_modes": distinct(r.get("permissionMode") for r in records),
        "skills": distinct(r.get("attributionSkill") for r in records),
        "counts": {
            "prompts": prompts,
            "assistant_turns": sum(1 for r in records if r.get("type") == "assistant"),
            "tools": tools,
        },
        "tokens": {"output": out_tokens, "cache_read": cache_tokens},
    }


def one_line(value, limit=TOOL_INPUT_CHARS):
    text = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)
    text = " ".join(text.split())
    return text[: limit - 1] + "…" if len(text) > limit else text


def tool_summary(block):
    """The most useful single field per tool, falling back to the whole input."""
    data = block.get("input") or {}
    # Cursor writes some inputs raw rather than as an object (ApplyPatch is a
    # patch string); `in` on a string would be a substring test, not a key.
    if not isinstance(data, dict):
        return one_line(data)
    for key in (
        "command",
        "file_path",
        "filePath",
        "url",
        "pattern",
        "query",
        "skill",
        "name",
        "prompt",
        "description",
    ):
        if key in data:
            return one_line(data[key])
    return one_line(data)


def question_event(block, result):
    """AskUserQuestion is split across the pair: prompt here, answer over there.

    The result half is a dict when the user answered, and a bare string when the
    call was rejected or interrupted ("User rejected tool use", or a rejection
    carrying what the user said instead). That string is the outcome, so keep it
    rather than rendering the question as unanswered.
    """
    outcome = result if isinstance(result, str) else None
    result = result if isinstance(result, dict) else {}
    answers = result.get("answers") or {}
    notes = result.get("annotations") or {}
    items = []
    for question in block.get("input", {}).get("questions", []):
        text = question.get("question", "")
        annotation = notes.get(text) or {}
        items.append(
            {
                "header": question.get("header"),
                "question": redact(text),
                "options": [
                    {
                        "label": o.get("label"),
                        "description": redact(o.get("description")),
                        "preview": redact(o.get("preview")),
                    }
                    for o in question.get("options", [])
                ],
                "answer": redact(answers.get(text)),
                "notes": redact(annotation.get("notes")),
                "outcome": redact(outcome),
            }
        )
    return items


def truncate_result(text, level):
    if level == "debug":
        return text, False
    lines = text.splitlines()
    clipped = "\n".join(lines[:RESULT_LINES])[:RESULT_CHARS]
    return clipped, clipped != text


def result_text(record):
    for block in blocks(record, "tool_result"):
        content = block.get("content")
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            return "\n".join(b.get("text", "") for b in content if isinstance(b, dict))
    return ""


COMMAND_RE = re.compile(r"<command-(name|args|message)>(.*?)</command-\1>", re.S)


def build_events(records, level):
    # Answers land on the record *after* the question, so index the pairs first.
    results = {}
    for record in records:
        payload = record.get("toolUseResult")
        for block in blocks(record, "tool_result"):
            if payload is not None:
                results[block.get("tool_use_id")] = payload

    events = []

    def emit(record, role, kind, **payload):
        events.append(
            {"ts": record.get("timestamp"), "role": role, "kind": kind, **payload}
        )

    for record in records:
        kind = record.get("type")

        if kind == "assistant":
            for block in record.get("message", {}).get("content", []):
                btype = block.get("type")
                if btype == "text":
                    emit(
                        record, "assistant", "text", text=redact(block.get("text", ""))
                    )
                elif btype == "thinking" and level == "debug":
                    # Never populated: the raw chain of thought is not returned,
                    # so only the replay signature survives. Marked, not hidden.
                    emit(
                        record,
                        "assistant",
                        "thinking",
                        signature_chars=len(block.get("signature", "")),
                    )
                elif btype == "tool_use":
                    if block.get("name") == "AskUserQuestion":
                        emit(
                            record,
                            "assistant",
                            "question",
                            items=question_event(block, results.get(block.get("id"))),
                        )
                    else:
                        event = {
                            "name": block.get("name"),
                            "summary": redact(tool_summary(block)),
                        }
                        if level in ("full", "debug"):
                            event["input"] = json.loads(
                                redact(json.dumps(block.get("input") or {}))
                            )
                        emit(record, "assistant", "tool_use", **event)

        elif kind == "user":
            content = record.get("message", {}).get("content")
            if isinstance(content, str):
                if record.get("isMeta"):
                    if level == "debug":
                        emit(record, "user", "meta", text=redact(content))
                    continue
                if content.startswith("<task-notification>") and level == "llm":
                    continue
                found = dict((k, v.strip()) for k, v in COMMAND_RE.findall(content))
                if found:
                    emit(
                        record,
                        "user",
                        "command",
                        name=found.get("name"),
                        args=found.get("args"),
                    )
                elif content.startswith("<local-command-stdout>"):
                    if level in ("full", "debug"):
                        emit(
                            record,
                            "user",
                            "command_output",
                            text=redact(one_line(content, 200)),
                        )
                else:
                    emit(record, "user", "text", text=redact(content))
                continue

            for block in blocks(record, "text"):
                emit(record, "user", "text", text=redact(block.get("text", "")))

            if level in ("llm", "brief"):
                continue
            for block in blocks(record, "tool_result"):
                # toolUseResult is a dict for structured tools and a bare string
                # for most others — only the dict form carries question answers.
                payload = results.get(block.get("tool_use_id"))
                if isinstance(payload, dict) and payload.get("answers"):
                    continue  # already rendered as the question's answer
                text, clipped = truncate_result(result_text(record), level)
                emit(
                    record,
                    "assistant",
                    "tool_result",
                    text=redact(text),
                    truncated=clipped,
                )

        elif kind == "system":
            subtype = record.get("subtype")
            if subtype == "away_summary":
                emit(
                    record,
                    "assistant",
                    "summary",
                    text=redact(record.get("content", "")),
                )
            elif level in ("full", "debug"):
                emit(
                    record,
                    "assistant",
                    "system",
                    subtype=subtype,
                    text=redact(str(record.get("content") or "")),
                )

        elif kind == "attachment" and level == "debug":
            emit(
                record,
                "assistant",
                "attachment",
                attachment_type=record.get("attachment", {}).get("type"),
            )

    return events


# --- parsing: opencode ------------------------------------------------------
#
# Read the database rather than shelling out to `opencode export --sanitize`:
# that command emits one session's JSON but cannot back `--list` or the picker
# (`opencode session list` prints a table only), and it boots a server per call.
# The cost of reading directly is a private schema — hence the SQLite fixture in
# selftest(), which is what will catch the next migration.

SESSION_COLUMNS = """
    id, title, slug, directory, agent, version, cost,
    tokens_input, tokens_output, tokens_reasoning,
    tokens_cache_read, tokens_cache_write,
    time_created, time_updated
"""


def stamp(millis):
    return (
        datetime.fromtimestamp(millis / 1000, timezone.utc)
        .isoformat(timespec="seconds")
        .replace("+00:00", "Z")
    )


def opencode_load(ref):
    """(session row, [(ts, message, [(ts, part), …]), …]) for one session."""
    with closing(connect(ref["db"])) as conn:
        session = conn.execute(
            f"select {SESSION_COLUMNS} from session where id = ?", (ref["id"],)
        ).fetchone()
        if session is None:
            sys.exit(f"session {ref['id']!r} not found in {ref['db']}")

        parts = {}
        for row in conn.execute(
            "select message_id, time_created, data from part"
            " where session_id = ? order by time_created, id",
            (ref["id"],),
        ):
            parts.setdefault(row["message_id"], []).append(
                (row["time_created"], json.loads(row["data"]))
            )

        messages = [
            (row["time_created"], json.loads(row["data"]), parts.get(row["id"], []))
            for row in conn.execute(
                "select id, time_created, data from message"
                " where session_id = ? order by time_created, id",
                (ref["id"],),
            )
        ]
    return session, messages


def model_label(message):
    """User and assistant messages spell the model out differently."""
    model = message.get("model")
    if isinstance(model, dict):
        provider = model.get("providerID")
        name = model.get("modelID") or model.get("id")
        variant = model.get("variant")
    else:
        provider = message.get("providerID")
        name = message.get("modelID")
        variant = message.get("variant")
    if not name:
        return None
    return f"{provider}/{name}" + (f" ({variant})" if variant else "")


def opencode_meta(ref, session, messages):
    tools = {}
    prompts = turns = 0
    for _, message, parts in messages:
        if message.get("role") == "user":
            prompts += any(part.get("type") == "text" for _, part in parts)
        else:
            turns += 1
        for _, part in parts:
            if part.get("type") == "tool":
                name = part.get("tool")
                tools[name] = tools.get(name, 0) + 1

    started = messages[0][0] if messages else session["time_created"]
    return {
        "tool": "opencode",
        "title": session["title"],
        "session_id": session["id"],
        "slug": session["slug"],
        "path": f"{ref['db']}#{session['id']}",
        "started": stamp(started),
        "ended": stamp(session["time_updated"]),
        "cwd": session["directory"],
        "git_branch": None,  # opencode records no branch anywhere
        "models": distinct(model_label(m) for _, m, _ in messages),
        "agents": distinct(
            [session["agent"]] + [m.get("agent") for _, m, _ in messages]
        ),
        "client_version": distinct([session["version"]]),
        "counts": {"prompts": prompts, "assistant_turns": turns, "tools": tools},
        "tokens": {
            "input": session["tokens_input"],
            "output": session["tokens_output"],
            "reasoning": session["tokens_reasoning"],
            "cache_read": session["tokens_cache_read"],
            "cache_write": session["tokens_cache_write"],
        },
        "cost": session["cost"],
    }


def opencode_question(state):
    """Answers ride on the same part as the question, indexed by position."""
    answers = (state.get("metadata") or {}).get("answers") or []
    items = []
    for index, question in enumerate(state.get("input", {}).get("questions", [])):
        picked = answers[index] if index < len(answers) else []
        items.append(
            {
                "header": question.get("header"),
                "question": redact(question.get("question", "")),
                "options": [
                    {
                        "label": o.get("label"),
                        "description": redact(o.get("description")),
                        "preview": None,  # opencode's question tool has no previews
                    }
                    for o in question.get("options", [])
                ],
                "answer": redact(picked[0] if picked else None),
                "notes": None,
                "outcome": redact(state.get("error")),
            }
        )
    return items


def opencode_events(messages, level):
    """One `tool` part becomes a tool_use/tool_result pair, so every level gate
    and the run-collapsing below work on both sources unchanged.

    Never emitted at any level: part-level `metadata` (multi-KB encrypted
    provider payloads) and the unified diffs inlined on user messages — the
    `patch` parts already say which files a turn touched.
    """
    events = []

    def emit(ts, role, kind, **payload):
        events.append({"ts": stamp(ts), "role": role, "kind": kind, **payload})

    for _, message, parts in messages:
        role = "user" if message.get("role") == "user" else "assistant"

        for ts, part in parts:
            ptype = part.get("type")

            if ptype == "text":
                text = part.get("text") or ""
                if text.strip():
                    emit(ts, role, "text", text=redact(text))

            elif ptype == "reasoning" and level == "debug":
                emit(ts, "assistant", "reasoning", text=redact(part.get("text") or ""))

            elif ptype == "patch" and level in ("full", "debug"):
                emit(ts, "assistant", "patch", files=part.get("files") or [])

            elif ptype == "tool":
                state = part.get("state") or {}
                if part.get("tool") == "question":
                    emit(ts, "assistant", "question", items=opencode_question(state))
                    continue

                event = {
                    "name": part.get("tool"),
                    "summary": redact(tool_summary({"input": state.get("input")})),
                }
                if level in ("full", "debug"):
                    event["input"] = json.loads(
                        redact(json.dumps(state.get("input") or {}))
                    )
                emit(ts, "assistant", "tool_use", **event)

                if level in ("llm", "brief"):
                    continue
                error = state.get("error")
                body = f"error: {error}" if error else (state.get("output") or "")
                if not body:
                    continue
                text, clipped = truncate_result(body, level)
                emit(
                    ts,
                    "assistant",
                    "tool_result",
                    text=redact(text),
                    truncated=clipped,
                )

    return events


# --- parsing: Cursor -----------------------------------------------------------
#
# `~/.cursor/projects/<project>/agent-transcripts/<id>/<id>.jsonl`. Same
# content-block shape as Claude (text / tool_use) but a thinner envelope: no
# `type`, no per-line timestamp, no model, no tokens, and no tool_result —
# Cursor drops outputs upstream. User turns wrap the prompt in <timestamp>
# / <user_query> tags. `turn_ended` markers sit between model turns.
#
# Question answers never land in this file: AskQuestion is recorded as the
# call, then the next assistant line already knows the pick. Same projection
# as Claude's question event, minus the answer.


def cursor_question(block):
    data = block.get("input") or {}
    title = data.get("title")
    items = []
    for question in data.get("questions") or []:
        items.append(
            {
                "header": title or question.get("id"),
                "question": redact(question.get("prompt") or question.get("question") or ""),
                "options": [
                    {
                        "label": o.get("label"),
                        "description": redact(o.get("description")),
                        "preview": None,
                    }
                    for o in question.get("options") or []
                ],
                "answer": None,
                "notes": None,
                "outcome": None,
            }
        )
    return items


def cursor_meta(records, path):
    tools = {}
    prompts = 0
    turns = 0
    stamps = []
    title = ""
    for record in records:
        if record.get("role") == "user":
            text = cursor_user_text(record)
            if text:
                prompts += 1
                if not title:
                    title = text.splitlines()[0]
            ts = cursor_record_ts(record)
            if ts:
                stamps.append(ts)
        elif record.get("role") == "assistant":
            turns += 1
            content = record.get("message", {}).get("content")
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "tool_use":
                        name = block.get("name")
                        tools[name] = tools.get(name, 0) + 1
    mtime = iso_mtime(path)
    project = (
        path.parent.parent.parent.name if "agent-transcripts" in path.parts else None
    )
    return {
        "tool": "cursor",
        "title": redact(title) if title else None,
        "session_id": path.stem,
        "path": str(path),
        "started": stamps[0] if stamps else mtime,
        "ended": mtime,
        "cwd": project_label(project) if project else None,
        "git_branch": None,
        "models": [],
        "counts": {"prompts": prompts, "assistant_turns": turns, "tools": tools},
    }


def cursor_events(records, level):
    events = []
    last_ts = None

    def emit(role, kind, **payload):
        events.append({"ts": last_ts, "role": role, "kind": kind, **payload})

    for record in records:
        if record.get("type") == "turn_ended":
            status = record.get("status") or ""
            error = record.get("error") or status
            if status != "success" and level != "llm":
                emit("assistant", "summary", text=redact(error))
            elif level == "debug":
                emit("assistant", "system", subtype="turn_ended", text=status)
            continue

        role = record.get("role")
        ts = cursor_record_ts(record)
        if ts:
            last_ts = ts

        if role == "user":
            text = cursor_user_text(record)
            if text:
                emit("user", "text", text=redact(text))
            continue

        if role != "assistant":
            continue

        content = record.get("message", {}).get("content")
        if not isinstance(content, list):
            if isinstance(content, str) and content.strip():
                emit("assistant", "text", text=redact(content))
            continue

        for block in content:
            if not isinstance(block, dict):
                continue
            btype = block.get("type")
            if btype == "text":
                text = block.get("text") or ""
                if text.strip():
                    emit("assistant", "text", text=redact(text))
            elif btype == "thinking" and level == "debug":
                text = block.get("thinking") or block.get("text") or ""
                emit("assistant", "reasoning", text=redact(text))
            elif btype == "tool_use":
                if block.get("name") == "AskQuestion":
                    emit("assistant", "question", items=cursor_question(block))
                    continue
                event = {
                    "name": block.get("name"),
                    "summary": redact(tool_summary(block)),
                }
                if level in ("full", "debug"):
                    event["input"] = json.loads(
                        redact(json.dumps(block.get("input") or {}))
                    )
                emit("assistant", "tool_use", **event)
            elif btype == "tool_result" and level in ("full", "debug"):
                # Not observed in Cursor's own files; kept so a format change
                # that starts writing results still exports them.
                content_body = block.get("content")
                if isinstance(content_body, str):
                    text = content_body
                elif isinstance(content_body, list):
                    text = "\n".join(
                        b.get("text", "")
                        for b in content_body
                        if isinstance(b, dict)
                    )
                else:
                    text = ""
                if text:
                    text, clipped = truncate_result(text, level)
                    emit(
                        "assistant",
                        "tool_result",
                        text=redact(text),
                        truncated=clipped,
                    )

    return events


def collapse_tools(events, level):
    """Per-call lines are noise once a session runs long, so below `full` a
    contiguous run of calls becomes a single count (`brief`) or disappears
    (`llm`). Adjacency is the whole run boundary: prose, a question block, or a
    role change all sit between calls as events, so they split runs for free.
    """
    if level in ("full", "debug"):
        return events

    out = []
    run = []

    def flush():
        if not run:
            return
        counts = {}
        for event in run:
            counts[event["name"]] = counts.get(event["name"], 0) + 1
        if level == "brief":
            out.append(
                {
                    "ts": run[0]["ts"],
                    "role": "assistant",
                    "kind": "tool_stats",
                    "total": len(run),
                    # Sorted so an export of the same session is byte-stable.
                    "counts": dict(
                        sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
                    ),
                }
            )
        run.clear()

    for event in events:
        if event["kind"] == "tool_use":
            run.append(event)
            continue
        flush()
        out.append(event)
    flush()
    return out


# --- rendering --------------------------------------------------------------


def clock(stamp):
    try:
        return datetime.fromisoformat(stamp.replace("Z", "+00:00")).strftime("%H:%M")
    except (AttributeError, ValueError):
        return "??:??"


def day(stamp):
    try:
        return datetime.fromisoformat(stamp.replace("Z", "+00:00")).strftime("%Y-%m-%d")
    except (AttributeError, ValueError):
        return "unknown date"


def duration(meta):
    try:
        start = datetime.fromisoformat(meta["started"].replace("Z", "+00:00"))
        end = datetime.fromisoformat(meta["ended"].replace("Z", "+00:00"))
        return f"{int((end - start).total_seconds() // 60)}m"
    except (AttributeError, KeyError, ValueError):
        return "?"


def compact(value):
    return " → ".join(str(v) for v in value) if value else "—"


def tokens(count):
    if count >= 1_000_000:
        return f"{count / 1_000_000:.1f}M"
    return f"{count / 1000:.1f}k" if count >= 1000 else str(count)


def plural(count, noun):
    return f"{count} {noun}" + ("" if count == 1 else "s")


def render_header(meta, style):
    title = meta["title"] or "Agent session"
    where = meta["cwd"] or "?"
    if style == "minimal":
        branch = f" (branch {meta['git_branch']})" if meta["git_branch"] else ""
        return [
            f"# {title}",
            "",
            f"Session of {day(meta['started'])} in `{where}`{branch}.",
            "",
        ]

    counts = meta["counts"]
    tool_counts = ", ".join(
        f"{name} {n}"
        for name, n in sorted(counts["tools"].items(), key=lambda kv: -kv[1])
    )
    rows = [
        ("Session", meta["session_id"] or "?"),
        (
            "When",
            f"{day(meta['started'])} {clock(meta['started'])} → {clock(meta['ended'])} UTC ({duration(meta)})",
        ),
        (
            "Where",
            f"{where}"
            + (f" (branch {meta['git_branch']})" if meta["git_branch"] else ""),
        ),
        ("Model", compact(meta["models"])),
        (
            "Volume",
            f"{plural(counts['prompts'], 'prompt')} · {plural(counts['assistant_turns'], 'turn')} · {plural(sum(counts['tools'].values()), 'tool call')} ({tool_counts or 'none'})",
        ),
    ]
    # Each tool records what the other does not: no shared row full of dashes.
    if meta["tool"] == "claude":
        used = meta["tokens"]
        rows += [
            ("Effort", compact(meta["efforts"])),
            (
                "Client",
                f"Claude Code {compact(meta['client_version'])} · profile {meta['profile']} · mode {compact(meta['modes'])} · permissions {compact(meta['permission_modes'])}",
            ),
            (
                "Tokens",
                f"{tokens(used['output'])} out · {tokens(used['cache_read'])} cache read",
            ),
            ("Skills", ", ".join(meta["skills"]) or "—"),
        ]
    elif meta["tool"] == "opencode":
        used = meta["tokens"]
        rows += [
            ("Agent", compact(meta["agents"])),
            (
                "Client",
                f"opencode {compact(meta['client_version'])} · slug {meta['slug'] or '—'}",
            ),
            (
                "Tokens",
                f"{tokens(used['input'])} in · {tokens(used['output'])} out · {tokens(used['reasoning'])} reasoning · {tokens(used['cache_read'])} cache read",
            ),
            ("Cost", f"${meta['cost']:.2f}"),
        ]
    else:
        rows += [("Client", "Cursor")]

    out = [f"# {title}", "", "| | |", "|---|---|"]
    out += [f"| {label} | {value} |" for label, value in rows]
    out.append("")
    return out


def render_question(items, level):
    out = []
    for item in items:
        out.append(f"### ❓ {item['header'] or 'Question'}")
        out.append("")
        out.append(f"> {item['question']}")
        out.append("")
        for option in item["options"]:
            chosen = option["label"] == item["answer"]
            mark = "**" if chosen else ""
            out.append(
                f"- {mark}{option['label']}{mark}" + (" ← selected" if chosen else "")
            )
            if level in ("full", "debug"):
                if option["description"]:
                    out.append(f"  - {option['description']}")
                if option["preview"]:
                    out.append("")
                    out.append("    ```")
                    out += [f"    {line}" for line in option["preview"].splitlines()]
                    out.append("    ```")
        out.append("")
        if item["answer"]:
            out.append(f"**Answer:** {item['answer']}")
        if item["notes"]:
            out.append(f"**Notes:** {item['notes']}")
        if item["outcome"]:
            out.append(f"**Outcome:** {one_line(item['outcome'], 400)}")
        out.append("")
    return out


def render_markdown(meta, events, level, header):
    out = render_header(meta, header)
    who_agent = {
        "claude": "🤖 Claude",
        "opencode": "🤖 opencode",
        "cursor": "🤖 Cursor",
    }[meta["tool"]]
    role = None
    for event in events:
        if event["role"] != role:
            role = event["role"]
            out.append(
                f"## {'👤 User' if role == 'user' else who_agent} · {clock(event['ts'])}"
            )
            out.append("")

        kind = event["kind"]
        if kind == "text":
            out += [event["text"], ""]
        elif kind == "command":
            invocation = " ".join(filter(None, [event["name"], event.get("args")]))
            out += [f"*ran `{invocation}`*", ""]
        elif kind == "command_output":
            out += [f"*→ {event['text']}*", ""]
        elif kind == "tool_use":
            out.append(f"`{event['name']}` {event['summary']}")
            if level in ("full", "debug") and event.get("input"):
                out += [
                    "",
                    "```json",
                    json.dumps(event["input"], indent=2, ensure_ascii=False),
                    "```",
                    "",
                ]
        elif kind == "tool_stats":
            breakdown = ", ".join(f"{name} {n}" for name, n in event["counts"].items())
            out += [f"*{plural(event['total'], 'tool call')}: {breakdown}*", ""]
        elif kind == "tool_result":
            out += [
                "",
                "```",
                event["text"] + ("\n… (truncated)" if event["truncated"] else ""),
                "```",
                "",
            ]
        elif kind == "question":
            out += render_question(event["items"], level)
        elif kind == "summary":
            out += [f"*Recap: {event['text']}*", ""]
        elif kind == "reasoning":
            out += ["*[reasoning]*"]
            out += [f"> {line}" for line in event["text"].splitlines()]
            out.append("")
        elif kind == "patch":
            out += [f"*[patch: {one_line(', '.join(event['files']), 200)}]*", ""]
        elif kind == "thinking":
            out += [
                f"*[thinking · {event['signature_chars']}-char signature · text not recorded]*",
                "",
            ]
        elif kind == "system":
            out += [f"*[{event['subtype']}]* {event['text']}", ""]
        elif kind == "meta":
            out += [f"*[meta]* {one_line(event['text'], 200)}", ""]
        elif kind == "attachment":
            out += [f"*[attachment: {event['attachment_type']}]*", ""]
    return "\n".join(out).rstrip() + "\n"


def render_json(meta, events, header):
    if header == "minimal":
        meta = {
            k: meta[k]
            for k in ("tool", "title", "session_id", "started", "cwd", "git_branch")
        }
    return (
        json.dumps({"session": meta, "events": events}, indent=2, ensure_ascii=False)
        + "\n"
    )


# --- entry point ------------------------------------------------------------


def export(ref, level, header, as_json):
    if ref["tool"] == "claude":
        records = load(ref["path"])
        meta = build_meta(records, ref["path"])
        # ponytail: file order, not a parentUuid walk. The log is append-only and
        # chronological, and every fork observed so far is an assistant/user pair
        # at the same millisecond rather than a rewind. Discarded alternative:
        # walk back from the last leaf — with 12 leaves in a 341-line session,
        # picking "the" leaf is a heuristic that silently drops most of the
        # transcript when wrong. Untested case is a real rewind (edited message),
        # which would show the abandoned branch here. Add --thread if that bites.
        events = build_events(records, level)
    elif ref["tool"] == "opencode":
        session, messages = opencode_load(ref)
        meta = opencode_meta(ref, session, messages)
        events = opencode_events(messages, level)
    else:
        records = load(ref["path"])
        meta = cursor_meta(records, ref["path"])
        events = cursor_events(records, level)

    events = collapse_tools(events, level)
    return (
        render_json(meta, events, header)
        if as_json
        else render_markdown(meta, events, level, header)
    )


FIXTURE = [
    {"type": "ai-title", "aiTitle": "Fixture session", "sessionId": "s1"},
    {
        "type": "user",
        "timestamp": "2026-01-01T10:00:00.000Z",
        "sessionId": "s1",
        "cwd": "/tmp/x",
        "message": {
            "role": "user",
            "content": "hello, my key is sk-ant-oat01-DEADBEEFDEADBEEF",
        },
    },
    {
        "type": "assistant",
        "timestamp": "2026-01-01T10:00:01.000Z",
        "effort": "xhigh",
        "version": "9.9.9",
        "message": {
            "model": "claude-opus-5",
            "usage": {"output_tokens": 10, "cache_read_input_tokens": 2000},
            "content": [
                {"type": "thinking", "thinking": "", "signature": "x" * 42},
                {
                    "type": "tool_use",
                    "id": "t1",
                    "name": "Bash",
                    "input": {"command": "rg -n secret ."},
                },
                {
                    "type": "tool_use",
                    "id": "q1",
                    "name": "AskUserQuestion",
                    "input": {
                        "questions": [
                            {
                                "question": "Which?",
                                "header": "Pick",
                                "options": [
                                    {
                                        "label": "A",
                                        "description": "first",
                                        "preview": "code()",
                                    },
                                    {"label": "B", "description": "second"},
                                ],
                            }
                        ]
                    },
                },
                {
                    "type": "tool_use",
                    "id": "q2",
                    "name": "AskUserQuestion",
                    "input": {
                        "questions": [
                            {
                                "question": "Also?",
                                "header": "Second",
                                "options": [{"label": "C"}],
                            }
                        ]
                    },
                },
            ],
        },
    },
    {
        "type": "user",
        "timestamp": "2026-01-01T10:00:02.000Z",
        "toolUseResult": "out",
        "message": {
            "role": "user",
            "content": [
                {"type": "tool_result", "tool_use_id": "t1", "content": "line\n" * 50}
            ],
        },
    },
    {
        "type": "user",
        "timestamp": "2026-01-01T10:00:03.000Z",
        "toolUseResult": {
            "answers": {"Which?": "B"},
            "annotations": {"Which?": {"notes": "with a caveat"}},
        },
        "message": {
            "role": "user",
            "content": [
                {"type": "tool_result", "tool_use_id": "q1", "content": "answered"}
            ],
        },
    },
    # A rejected question: toolUseResult is a bare string, not the answers dict.
    {
        "type": "user",
        "timestamp": "2026-01-01T10:00:04.000Z",
        "toolUseResult": "User rejected tool use",
        "message": {
            "role": "user",
            "content": [
                {"type": "tool_result", "tool_use_id": "q2", "content": "rejected"}
            ],
        },
    },
    # A run of several calls in a row: the case the collapsed line exists for.
    {
        "type": "assistant",
        "timestamp": "2026-01-01T10:00:04.500Z",
        "message": {
            "model": "claude-opus-5",
            "content": [
                {
                    "type": "tool_use",
                    "id": "t2",
                    "name": "Read",
                    "input": {"file_path": "/tmp/x/a"},
                },
                {
                    "type": "tool_use",
                    "id": "t3",
                    "name": "Read",
                    "input": {"file_path": "/tmp/x/b"},
                },
                {
                    "type": "tool_use",
                    "id": "t4",
                    "name": "Bash",
                    "input": {"command": "ls"},
                },
            ],
        },
    },
    {
        "type": "system",
        "subtype": "away_summary",
        "timestamp": "2026-01-01T10:00:05.000Z",
        "content": "Goal: ship it.",
    },
]

# 2026-01-01T10:00:00Z, in the epoch milliseconds opencode stores.
OC_BASE = 1767261600000

OC_SCHEMA = """
create table session (
  id text primary key, parent_id text, title text, slug text, directory text,
  agent text, version text, cost real,
  tokens_input integer, tokens_output integer, tokens_reasoning integer,
  tokens_cache_read integer, tokens_cache_write integer,
  time_created integer, time_updated integer);
create table message (
  id text primary key, session_id text, time_created integer, data text);
create table part (
  id text primary key, message_id text, session_id text,
  time_created integer, data text);
"""

OC_MESSAGES = [
    (
        "m1",
        0,
        {"role": "user", "model": {"providerID": "github-copilot", "modelID": "gpt-5"}},
        [{"type": "text", "text": "hello, my key is sk-ant-oat01-DEADBEEFDEADBEEF"}],
    ),
    (
        "m2",
        1000,
        {"role": "assistant", "providerID": "github-copilot", "modelID": "gpt-5"},
        [
            {"type": "step-start", "snapshot": "abc"},
            {"type": "reasoning", "text": "weighing the options"},
            {
                "type": "tool",
                "tool": "bash",
                "state": {
                    "status": "completed",
                    "input": {"command": "rg -n secret ."},
                    "output": "line\n" * 50,
                },
                # Provider blobs must never reach the export.
                "metadata": {"copilot": {"reasoningEncryptedContent": "BLOBBLOB"}},
            },
            {
                "type": "tool",
                "tool": "question",
                "state": {
                    "status": "completed",
                    "input": {
                        "questions": [
                            {
                                "question": "Which?",
                                "header": "Pick",
                                "options": [
                                    {"label": "A", "description": "first"},
                                    {"label": "B", "description": "second"},
                                ],
                            }
                        ]
                    },
                    "output": "User has answered your questions",
                    "metadata": {"answers": [["B"]]},
                },
            },
            {
                "type": "tool",
                "tool": "question",
                "state": {
                    "status": "error",
                    "input": {
                        "questions": [
                            {
                                "question": "Also?",
                                "header": "Second",
                                "options": [{"label": "C"}],
                            }
                        ]
                    },
                    "error": "The user dismissed this question",
                },
            },
            {"type": "patch", "hash": "deadbeef", "files": ["/tmp/x/a"]},
            {"type": "step-finish", "reason": "tool-calls"},
        ],
    ),
    (
        "m3",
        2000,
        {"role": "assistant", "providerID": "github-copilot", "modelID": "gpt-5.1"},
        [
            {
                "type": "tool",
                "tool": "read",
                "state": {
                    "status": "completed",
                    "input": {"filePath": "/tmp/x/a"},
                    "output": "a",
                },
            },
            {
                "type": "tool",
                "tool": "read",
                "state": {
                    "status": "completed",
                    "input": {"filePath": "/tmp/x/b"},
                    "output": "b",
                },
            },
            {
                "type": "tool",
                "tool": "bash",
                "state": {
                    "status": "error",
                    "input": {"command": "false"},
                    "error": "exit 1",
                },
            },
        ],
    ),
]


def write_opencode_fixture(db_path):
    conn = sqlite3.connect(db_path)
    conn.executescript(OC_SCHEMA)
    conn.execute(
        "insert into session values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (
            "ses_test",
            None,
            "Fixture session",
            "misty-lagoon",
            "/tmp/x",
            "build",
            "1.18.13",
            0.12,
            1000,
            200,
            300,
            4000,
            0,
            OC_BASE,
            OC_BASE + 5000,
        ),
    )
    for index, (mid, offset, message, parts) in enumerate(OC_MESSAGES):
        conn.execute(
            "insert into message values (?,?,?,?)",
            (mid, "ses_test", OC_BASE + offset, json.dumps(message)),
        )
        for position, part in enumerate(parts):
            conn.execute(
                "insert into part values (?,?,?,?,?)",
                (
                    f"p{index}_{position:02d}",
                    mid,
                    "ses_test",
                    OC_BASE + offset + position,
                    json.dumps(part),
                ),
            )
    conn.commit()
    conn.close()


def selftest_claude(tmp):
    path = Path(tmp) / "fixture.jsonl"
    path.write_text("\n".join(json.dumps(r) for r in FIXTURE))
    ref = claude_ref(path)

    brief = export(ref, "brief", "table", False)
    assert preview(json.dumps(ref, default=str)) == brief
    assert "sk-ant-" not in brief, "redaction did not fire"
    assert "[REDACTED]" in brief, "redacted marker missing"
    assert "```\nline" not in brief, "brief must not render tool_result bodies"
    assert "`Bash` rg -n secret ." not in brief, "brief must not render tool inputs"
    assert "*1 tool call: Bash 1*" in brief, "lone call lost its stats line"
    assert "*3 tool calls: Read 2, Bash 1*" in brief, (
        "a run must collapse into one line, counts ordered by frequency"
    )
    assert "**B** ← selected" in brief, "answer not marked"
    assert "with a caveat" in brief, "free-text notes dropped"
    assert "**Outcome:** User rejected tool use" in brief, (
        "rejected question lost its outcome"
    )
    assert "Recap: Goal: ship it." in brief, "away_summary dropped"
    assert "thinking" not in brief, "thinking marker leaked into brief"

    full = export(ref, "full", "table", False)
    assert "… (truncated)" in full, "full must truncate long tool results"
    assert "first" in full, "full must render option descriptions"
    assert "`Bash` rg -n secret ." in full, "full must keep per-call detail"
    assert "tool calls:" not in full, "full must not collapse runs"

    debug = export(ref, "debug", "table", False)
    assert "42-char signature" in debug, "thinking marker missing at debug"
    assert "… (truncated)" not in debug, "debug must not truncate"

    llm = export(ref, "llm", "minimal", False)
    assert "Tokens" not in llm, "minimal header must drop token counts"
    assert "Session of 2026-01-01" in llm, "minimal header lost the date"
    assert "tool call" not in llm, "llm must not mention tool calls at all"
    assert "Bash" not in llm, "llm leaked a tool name"
    assert "```\nline" not in llm, "llm must not render tool_result bodies"
    assert "**B** ← selected" in llm, "llm dropped the question substance"

    task_notification = {
        "type": "user",
        "timestamp": "2026-01-01T10:00:05.500Z",
        "message": {
            "role": "user",
            "content": "<task-notification>\n<summary>completed</summary>\n</task-notification>",
        },
    }
    assert not build_events([task_notification], "llm"), (
        "llm must drop task lifecycle notifications"
    )
    assert build_events([task_notification], "full")[0]["kind"] == "text", (
        "full must retain task lifecycle notifications"
    )

    payload = json.loads(export(ref, "brief", "table", True))
    assert payload["session"]["counts"]["tools"] == {
        "Bash": 2,
        "AskUserQuestion": 2,
        "Read": 2,
    }
    assert not [e for e in payload["events"] if e["kind"] == "tool_use"], (
        "brief JSON must carry stats, not per-call events"
    )
    assert [e for e in payload["events"] if e["kind"] == "tool_stats"][-1] == {
        "ts": "2026-01-01T10:00:04.500Z",
        "role": "assistant",
        "kind": "tool_stats",
        "total": 3,
        "counts": {"Read": 2, "Bash": 1},
    }
    assert payload["events"][-1]["kind"] == "summary"
    question = next(e for e in payload["events"] if e["kind"] == "question")
    assert question["items"][0]["answer"] == "B"


def selftest_opencode(tmp):
    db = Path(tmp) / "opencode-test.db"
    write_opencode_fixture(db)
    ref = opencode_ref(db, "ses_test")

    brief = export(ref, "brief", "table", False)
    assert preview(json.dumps(ref, default=str)) == brief
    assert "sk-ant-" not in brief, "redaction did not fire"
    assert "[REDACTED]" in brief, "redacted marker missing"
    assert "```\nline" not in brief, "brief must not render tool_result bodies"
    assert "*1 tool call: bash 1*" in brief, "lone call lost its stats line"
    assert "*3 tool calls: read 2, bash 1*" in brief, (
        "a run must collapse into one line, counts ordered by frequency"
    )
    assert "**B** ← selected" in brief, "answer not marked"
    assert "**Outcome:** The user dismissed this question" in brief, (
        "dismissed question lost its outcome"
    )
    assert "*[reasoning]*" not in brief, "reasoning is debug-only"
    assert "step-start" not in brief, "step bookkeeping leaked"
    assert "$0.12" in brief, "opencode header lost the cost row"
    assert "github-copilot/gpt-5 → github-copilot/gpt-5.1" in brief, (
        "mid-session model switch not reported"
    )

    full = export(ref, "full", "table", False)
    assert "… (truncated)" in full, "full must truncate long tool results"
    assert "`bash` rg -n secret ." in full, "full must keep per-call detail"
    assert "`read` /tmp/x/a" in full, "filePath inputs must summarize"
    assert "*[patch: /tmp/x/a]*" in full, "patch parts must render at full"
    assert "error: exit 1" in full, "a failed call must show its error"
    assert "*[reasoning]*" not in full, "reasoning is debug-only"
    assert "BLOBBLOB" not in full, "provider metadata leaked into the export"

    debug = export(ref, "debug", "table", False)
    assert "*[reasoning]*" in debug, "reasoning missing at debug"
    assert "weighing the options" in debug, "reasoning text missing at debug"
    assert "… (truncated)" not in debug, "debug must not truncate"
    assert "BLOBBLOB" not in debug, "provider metadata leaked at debug"

    llm = export(ref, "llm", "minimal", False)
    assert "Session of 2026-01-01" in llm, "minimal header lost the date"
    assert "bash" not in llm, "llm leaked a tool name"
    assert "**B** ← selected" in llm, "llm dropped the question substance"

    payload = json.loads(export(ref, "brief", "table", True))
    assert payload["session"]["tool"] == "opencode"
    assert payload["session"]["counts"] == {
        "prompts": 1,
        "assistant_turns": 2,
        "tools": {"bash": 2, "question": 2, "read": 2},
    }
    assert payload["session"]["tokens"]["reasoning"] == 300
    assert payload["events"][0]["ts"] == "2026-01-01T10:00:00Z", (
        "epoch milliseconds must normalize to ISO"
    )


CURSOR_FIXTURE = [
    {
        "role": "user",
        "message": {
            "content": [
                {
                    "type": "text",
                    "text": (
                        "<timestamp>Friday, Jan 01, 2026, 10:00 AM (UTC)</timestamp>\n"
                        "<user_query>\nhello, my key is sk-ant-oat01-DEADBEEFDEADBEEF\n"
                        "</user_query>"
                    ),
                }
            ]
        },
    },
    {
        "role": "assistant",
        "message": {
            "content": [
                {"type": "thinking", "thinking": "weighing the options"},
                {"type": "text", "text": "looking"},
                {
                    "type": "tool_use",
                    "name": "Shell",
                    "input": {"command": "rg -n secret ."},
                },
                {
                    "type": "tool_use",
                    "name": "AskQuestion",
                    "input": {
                        "title": "Pick",
                        "questions": [
                            {
                                "id": "which",
                                "prompt": "Which?",
                                "options": [
                                    {"id": "a", "label": "A", "description": "first"},
                                    {"id": "b", "label": "B", "description": "second"},
                                ],
                            }
                        ],
                    },
                },
            ]
        },
    },
    {
        "role": "assistant",
        "message": {
            "content": [
                {
                    "type": "tool_use",
                    "name": "Read",
                    "input": {"file_path": "/tmp/x/a"},
                },
                {
                    "type": "tool_use",
                    "name": "Read",
                    "input": {"file_path": "/tmp/x/b"},
                },
                {
                    "type": "tool_use",
                    "name": "Shell",
                    "input": {"command": "ls"},
                },
            ]
        },
    },
    {
        "role": "assistant",
        "message": {
            "content": [
                # Cursor writes ApplyPatch's input as a raw patch string.
                {
                    "type": "tool_use",
                    "name": "ApplyPatch",
                    "input": "*** Begin Patch\n*** Update File: /tmp/x/a\n",
                },
            ]
        },
    },
    {"type": "turn_ended", "status": "success"},
    {"type": "turn_ended", "status": "aborted", "error": "User aborted/interrupted manually."},
]


def selftest_cursor(tmp):
    path = Path(tmp) / "cursor-fixture.jsonl"
    path.write_text("\n".join(json.dumps(r) for r in CURSOR_FIXTURE))
    os.utime(path, (OC_BASE / 1000, OC_BASE / 1000 + 5))
    ref = cursor_ref(path)
    assert jsonl_ref(path)["tool"] == "cursor"

    brief = export(ref, "brief", "table", False)
    assert preview(json.dumps(ref, default=str)) == brief
    assert "sk-ant-" not in brief, "redaction did not fire"
    assert "[REDACTED]" in brief, "redacted marker missing"
    assert "<timestamp>" not in brief, "wrapper tags leaked into the chat"
    assert "<user_query>" not in brief
    assert "```\nline" not in brief, "brief must not invent tool_result bodies"
    assert "`Shell` rg -n secret ." not in brief, "brief must not render tool inputs"
    assert "*1 tool call: Shell 1*" in brief, "lone call lost its stats line"
    assert "*4 tool calls: Read 2, ApplyPatch 1, Shell 1*" in brief, (
        "a run must collapse into one line, counts ordered by frequency"
    )
    assert "### ❓ Pick" in brief, "AskQuestion dropped"
    assert "- A" in brief and "- B" in brief, "question options dropped"
    assert "**B** ← selected" not in brief, "Cursor logs no answers; do not invent one"
    assert "Recap: User aborted/interrupted manually." in brief, (
        "aborted turn_ended lost its outcome"
    )
    assert "turn_ended" not in brief, "successful turn_ended leaked into brief"
    assert "*[reasoning]*" not in brief, "thinking is debug-only"
    assert "Client | Cursor" in brief or "| Client | Cursor |" in brief
    assert "🤖 Cursor" in brief

    full = export(ref, "full", "table", False)
    assert "`Shell` rg -n secret ." in full, "full must keep per-call detail"
    assert "`ApplyPatch` *** Begin Patch" in full, "raw-string tool input dropped"
    assert "first" in full, "full must render option descriptions"
    assert "tool calls:" not in full, "full must not collapse runs"
    assert "```\nline" not in full, "Cursor transcripts have no tool_result to render"

    debug = export(ref, "debug", "table", False)
    assert "*[reasoning]*" in debug, "thinking missing at debug"
    assert "weighing the options" in debug, "thinking text missing at debug"
    assert "*[turn_ended]* success" in debug, "successful turn_ended missing at debug"

    llm = export(ref, "llm", "minimal", False)
    assert "Session of 2026-01-01" in llm, "minimal header lost the date"
    assert "Shell" not in llm, "llm leaked a tool name"
    assert "Which?" in llm, "llm dropped the question substance"
    assert "aborted" not in llm, "llm must drop turn_ended abort recap"

    payload = json.loads(export(ref, "brief", "table", True))
    assert payload["session"]["tool"] == "cursor"
    assert payload["session"]["session_id"] == "cursor-fixture"
    assert payload["session"]["started"] == "2026-01-01T10:00:00Z"
    assert payload["session"]["counts"]["tools"] == {
        "Shell": 2,
        "AskQuestion": 1,
        "Read": 2,
        "ApplyPatch": 1,
    }
    question = next(e for e in payload["events"] if e["kind"] == "question")
    assert question["items"][0]["answer"] is None
    assert payload["events"][0]["ts"] == "2026-01-01T10:00:00Z"
    assert payload["events"][0]["text"] == (
        "hello, my key is [REDACTED]"
    )


def selftest_delete(tmp):
    root = Path(tmp) / "delete" / "profile"
    project = root / "projects" / "-a-b"
    sid, keep = "11111111-aaaa", "22222222-bbbb"
    for name in (sid, keep):
        (project / name / "tool-results").mkdir(parents=True)
        (project / f"{name}.jsonl").write_text("{}\n")
        (root / "file-history" / name).mkdir(parents=True)
        (root / "session-env" / name).mkdir(parents=True)
    ref = claude_ref(project / f"{sid}.jsonl")
    assert sorted(session_paths(ref)) == sorted(
        [
            project / f"{sid}.jsonl",
            project / sid,
            root / "file-history" / sid,
            root / "session-env" / sid,
        ]
    )
    for path in session_paths(ref):
        remove(path)
    assert session_paths(ref) == []
    assert len(session_paths(claude_ref(project / f"{keep}.jsonl"))) == 4

    transcript = Path(tmp) / "delete" / "cursor" / "agent-transcripts" / sid / f"{sid}.jsonl"
    transcript.parent.mkdir(parents=True)
    transcript.write_text("{}\n")
    assert session_paths(cursor_ref(transcript)) == [transcript.parent]
    assert session_paths(opencode_ref(Path(tmp) / "x.db", "ses_1")) == []
    assert human_size(512) == "512B"
    assert human_size(1536) == "1.5K"
    assert home_relative(Path.home() / "a") == "~/a"


def selftest():
    assert mangle("/Users/x/code/github.com/o/a_b") == "-Users-x-code-github-com-o-a-b"
    assert cursor_project_name("/Users/x/code/github.com/o/a_b") == (
        "Users-x-code-github-com-o-a-b"
    )
    assert cursor_clock_to_iso("Friday, Sep 11, 2026, 12:20 AM (UTC+2)") == (
        "2026-09-10T22:20:00Z"
    )
    assert cursor_clock_to_iso("Friday, Jan 01, 2026, 10:00 AM (UTC)") == (
        "2026-01-01T10:00:00Z"
    )
    assert profile_name(Path("/h/.config/trv-claude/projects/-a-b/s.jsonl")) == (
        "trv-claude"
    )
    assert profile_name(Path("/h/.claude/projects/-a-b/s.jsonl")) == "claude"
    assert project_label(mangle(Path.home() / "code/o/repo")) == "code-o-repo"
    assert project_label(cursor_project_name(Path.home() / "code/o/repo")) == (
        "code-o-repo"
    )
    assert project_label("-etc-nixos") == "etc-nixos"
    assert column("abc", 5) == "abc  "
    assert column("abcdef", 4) == "\u2026def"
    with tempfile.TemporaryDirectory() as tmp:
        selftest_claude(tmp)
        selftest_opencode(tmp)
        selftest_cursor(tmp)
        selftest_delete(tmp)
    print("selftest ok")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "session", nargs="?", help="path to a .jsonl transcript, or a session id"
    )
    levels = parser.add_mutually_exclusive_group()
    levels.add_argument(
        "--full", action="store_true", help="include tool results and question detail"
    )
    levels.add_argument("--debug", action="store_true", help="everything, untruncated")
    levels.add_argument(
        "--llm",
        action="store_true",
        help="preset for reseeding a fresh session: brief + minimal header",
    )
    parser.add_argument(
        "--json", action="store_true", help="normalized JSON instead of Markdown"
    )
    parser.add_argument(
        "--list", action="store_true", help="list sessions for the current project"
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="search every project on this machine, not just the current directory",
    )
    parser.add_argument(
        "--delete",
        action="store_true",
        help="pick sessions (Tab marks several), confirm, then delete them",
    )
    parser.add_argument("--selftest", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--preview", metavar="REF", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.selftest:
        return selftest()
    if args.preview:
        sys.stdout.write(preview(args.preview))
        return
    if args.list:
        return list_sessions(args.all)
    if args.delete:
        return delete_sessions(args.all)

    level, header = "brief", "table"
    if args.full:
        level = "full"
    elif args.debug:
        level = "debug"
    elif args.llm:
        level, header = "llm", "minimal"

    sys.stdout.write(export(resolve(args.session, args.all), level, header, args.json))


if __name__ == "__main__":
    main()
