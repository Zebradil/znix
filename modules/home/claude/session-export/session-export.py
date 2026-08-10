#!/usr/bin/env python3
"""Export a Claude Code session transcript as readable Markdown or JSON.

The transcript is an append-only event log, not a message list. Rendering a
"chat" is a projection over it: assistant prose lives in `text` blocks, but the
substance of a driven session often lives in AskUserQuestion payloads (question,
options, and the answer/notes recorded on the *result* half of the pair), so
scraping `text` alone yields almost nothing.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
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

LEVELS = ("brief", "full", "debug")
PRESETS = {"llm": {"level": "brief", "header": "minimal"}}


def redact(text):
    if not text:
        return text
    for pattern in REDACTIONS:
        text = pattern.sub("[REDACTED]", text)
    return text


# --- locating sessions ------------------------------------------------------


def project_roots():
    """Config roots to search, in precedence order."""
    roots = []
    env = os.environ.get("CLAUDE_CONFIG_DIR")
    if env:
        roots.append(Path(env) / "projects")
    roots.append(Path.home() / ".claude" / "projects")
    return [r for r in roots if r.is_dir()]


def project_dir_for_cwd():
    """Claude Code mangles the cwd into the project dir name: / -> -."""
    mangled = str(Path.cwd()).replace("/", "-")
    for root in project_roots():
        candidate = root / mangled
        if candidate.is_dir():
            return candidate
    return None


def session_files(scope=None):
    dirs = (
        [scope]
        if scope
        else [d for r in project_roots() for d in r.iterdir() if d.is_dir()]
    )
    files = [f for d in dirs for f in d.glob("*.jsonl")]
    return sorted(files, key=lambda f: f.stat().st_mtime, reverse=True)


def resolve(arg):
    """A path, or a bare session id looked up across every project dir."""
    if arg:
        candidate = Path(arg)
        if candidate.is_file():
            return candidate
        for root in project_roots():
            hits = sorted(root.glob(f"*/{arg}*.jsonl"))
            if hits:
                return hits[0]
        sys.exit(
            f"no session matching {arg!r} under {[str(r) for r in project_roots()]}"
        )
    return pick()


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


def list_sessions(scope):
    for path in session_files(scope):
        sid, when, size, title = summarize(path)
        print(f"{sid[:8]}  {when}  {size:>6}  {title}")


def pick():
    if not shutil.which("fzf"):
        sys.exit(
            "no session given and fzf is not installed — pass a path or session id"
        )
    scope = project_dir_for_cwd()
    files = session_files(scope) or session_files(None)
    lines = []
    for path in files:
        _, when, size, title = summarize(path)
        lines.append(f"{path}\t{when}  {size:>6}  {title}")
    chosen = subprocess.run(
        ["fzf", "--with-nth=2..", "--delimiter=\t", "--prompt=session> "],
        input="\n".join(lines),
        capture_output=True,
        text=True,
    )
    if chosen.returncode != 0 or not chosen.stdout.strip():
        sys.exit("no session selected")
    return Path(chosen.stdout.split("\t", 1)[0])


# --- parsing ----------------------------------------------------------------


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
    def distinct(values):
        seen = []
        for value in values:
            if value and value not in seen:
                seen.append(value)
        return seen

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
        "title": (
            [r.get("aiTitle") for r in records if r.get("type") == "ai-title"] or [None]
        )[-1],
        "session_id": next(
            (r["sessionId"] for r in records if r.get("sessionId")), None
        ),
        "path": str(path),
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
    for key in ("command", "file_path", "url", "pattern", "query", "skill", "prompt"):
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

            if level == "brief":
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
    title = meta["title"] or "Claude Code session"
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
    tools = ", ".join(
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
        ("Model", f"{compact(meta['models'])} · effort {compact(meta['efforts'])}"),
        (
            "Client",
            f"Claude Code {compact(meta['client_version'])} · mode {compact(meta['modes'])} · permissions {compact(meta['permission_modes'])}",
        ),
        (
            "Volume",
            f"{plural(counts['prompts'], 'prompt')} · {plural(counts['assistant_turns'], 'turn')} · {plural(sum(counts['tools'].values()), 'tool call')} ({tools or 'none'})",
        ),
        (
            "Tokens",
            f"{tokens(meta['tokens']['output'])} out · {tokens(meta['tokens']['cache_read'])} cache read",
        ),
        ("Skills", ", ".join(meta["skills"]) or "—"),
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
    role = None
    for event in events:
        if event["role"] != role:
            role = event["role"]
            who = "👤 User" if role == "user" else "🤖 Claude"
            out.append(f"## {who} · {clock(event['ts'])}")
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
            k: meta[k] for k in ("title", "session_id", "started", "cwd", "git_branch")
        }
    return (
        json.dumps({"session": meta, "events": events}, indent=2, ensure_ascii=False)
        + "\n"
    )


# --- entry point ------------------------------------------------------------


def export(path, level, header, as_json):
    records = load(path)
    meta = build_meta(records, path)
    # ponytail: file order, not a parentUuid walk. The log is append-only and
    # chronological, and every fork observed so far is an assistant/user pair at
    # the same millisecond rather than a rewind. Discarded alternative: walk back
    # from the last leaf — with 12 leaves in a 341-line session, picking "the"
    # leaf is a heuristic that silently drops most of the transcript when wrong.
    # Untested case is a real rewind (edited message), which would show the
    # abandoned branch here. Add --thread if that ever bites.
    events = build_events(records, level)
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
    {
        "type": "system",
        "subtype": "away_summary",
        "timestamp": "2026-01-01T10:00:05.000Z",
        "content": "Goal: ship it.",
    },
]


def selftest():
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "fixture.jsonl"
        path.write_text("\n".join(json.dumps(r) for r in FIXTURE))

        brief = export(path, "brief", "table", False)
        assert "sk-ant-" not in brief, "redaction did not fire"
        assert "[REDACTED]" in brief, "redacted marker missing"
        assert "```\nline" not in brief, "brief must not render tool_result bodies"
        assert "`Bash` rg -n secret ." in brief, "tool call line missing"
        assert "**B** ← selected" in brief, "answer not marked"
        assert "with a caveat" in brief, "free-text notes dropped"
        assert "**Outcome:** User rejected tool use" in brief, (
            "rejected question lost its outcome"
        )
        assert "Recap: Goal: ship it." in brief, "away_summary dropped"
        assert "thinking" not in brief, "thinking marker leaked into brief"

        full = export(path, "full", "table", False)
        assert "… (truncated)" in full, "full must truncate long tool results"
        assert "first" in full, "full must render option descriptions"

        debug = export(path, "debug", "table", False)
        assert "42-char signature" in debug, "thinking marker missing at debug"
        assert "… (truncated)" not in debug, "debug must not truncate"

        llm = export(path, "brief", "minimal", False)
        assert "Tokens" not in llm, "minimal header must drop token counts"
        assert "Session of 2026-01-01" in llm, "minimal header lost the date"

        payload = json.loads(export(path, "brief", "table", True))
        assert payload["session"]["counts"]["tools"] == {
            "Bash": 1,
            "AskUserQuestion": 2,
        }
        assert payload["events"][-1]["kind"] == "summary"
        question = next(e for e in payload["events"] if e["kind"] == "question")
        assert question["items"][0]["answer"] == "B"
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
        return list_sessions(project_dir_for_cwd())

    level, header = "brief", "table"
    if args.full:
        level = "full"
    elif args.debug:
        level = "debug"
    elif args.llm:
        level, header = PRESETS["llm"]["level"], PRESETS["llm"]["header"]

    sys.stdout.write(export(resolve(args.session), level, header, args.json))


if __name__ == "__main__":
    main()
