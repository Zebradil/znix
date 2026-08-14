#!/usr/bin/env python3
"""Export a Claude Code or opencode session transcript as readable Markdown or JSON.

Two stores, one projection. Claude Code appends a JSONL event log per session;
opencode writes rows into SQLite (`session` / `message` / `part`). Both are
reduced to the same event list, so every renderer below is source-agnostic.

A "chat" is a projection over that log, not a message list: assistant prose
lives in text blocks, but the substance of a driven session often lives in a
question payload (the options, the answer, the notes recorded beside it), so
scraping prose alone yields almost nothing.
"""

import argparse
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from contextlib import closing
from datetime import datetime, timezone
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


def rows(scoped):
    """Both tools' sessions as picker rows, newest first."""
    found = []

    scope = project_dirs_for_cwd() if scoped else None
    if scope or not scoped:
        for path in session_files(scope):
            sid, when, size, title = summarize(path)
            found.append(
                {
                    "tool": "claude",
                    "label": profile_name(path),
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
        query = "select id, title, time_updated from session where parent_id is null"
        if scoped:
            query += " and directory = ?"
        with closing(connect(db)) as conn:
            for row in conn.execute(query, (cwd,) if scoped else ()):
                found.append(
                    {
                        "tool": "opencode",
                        "label": "opencode",
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

    return sorted(found, key=lambda r: r["sort"], reverse=True)


def scoped_rows():
    return rows(True) or rows(False)


def resolve(arg):
    """A path, or a bare session id looked up in either store."""
    if not arg:
        return pick()

    candidate = Path(arg)
    if candidate.is_file():
        return claude_ref(candidate)
    for root in project_roots():
        hits = sorted(root.glob(f"*/{arg}*.jsonl"))
        if hits:
            return claude_ref(hits[0])
    for db in opencode_dbs():
        with closing(connect(db)) as conn:
            hit = conn.execute(
                "select id from session where id like ? order by time_updated desc limit 1",
                (arg + "%",),
            ).fetchone()
        if hit:
            return opencode_ref(db, hit["id"])

    searched = [str(r) for r in project_roots()] + [str(d) for d in opencode_dbs()]
    sys.exit(f"no session matching {arg!r} under {searched}")


def list_sessions():
    for row in scoped_rows():
        print(
            f"{row['label']:15}  {row['id'][:12]}  {row['when']}  {row['size']:>6}  {row['title']}"
        )


def pick():
    if not shutil.which("fzf"):
        sys.exit(
            "no session given and fzf is not installed — pass a path or session id"
        )
    found = scoped_rows()
    lines = [
        f"{i}\t{row['label']:15}  {row['when']}  {row['size']:>6}  {row['title']}"
        for i, row in enumerate(found)
    ]
    chosen = subprocess.run(
        ["fzf", "--with-nth=2..", "--delimiter=\t", "--prompt=session> "],
        input="\n".join(lines),
        capture_output=True,
        text=True,
    )
    if chosen.returncode != 0 or not chosen.stdout.strip():
        sys.exit("no session selected")
    return found[int(chosen.stdout.split("\t", 1)[0])]["ref"]


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
    used = meta["tokens"]
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
    else:
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
    who_agent = "🤖 Claude" if meta["tool"] == "claude" else "🤖 opencode"
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
    else:
        session, messages = opencode_load(ref)
        meta = opencode_meta(ref, session, messages)
        events = opencode_events(messages, level)

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


def selftest():
    assert mangle("/Users/x/code/github.com/o/a_b") == "-Users-x-code-github-com-o-a-b"
    assert profile_name(Path("/h/.config/trv-claude/projects/-a-b/s.jsonl")) == (
        "trv-claude"
    )
    assert profile_name(Path("/h/.claude/projects/-a-b/s.jsonl")) == "claude"
    with tempfile.TemporaryDirectory() as tmp:
        selftest_claude(tmp)
        selftest_opencode(tmp)
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
    parser.add_argument("--selftest", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if args.selftest:
        return selftest()
    if args.list:
        return list_sessions()

    level, header = "brief", "table"
    if args.full:
        level = "full"
    elif args.debug:
        level = "debug"
    elif args.llm:
        level, header = "llm", "minimal"

    sys.stdout.write(export(resolve(args.session), level, header, args.json))


if __name__ == "__main__":
    main()
