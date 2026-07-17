"use strict";
// worklog-prep: the deterministic half of the /standup and /weekly skills.
// The skills do only the two things a script can't: semantic grouping and
// prose. Everything else — draining, collapsing sessions, computing the
// window, running the source commands, naming the report file, advancing the
// marker — lives here and is emitted as one JSON blob on stdout.
//
// Subcommands:
//   standup [--dry-run]   drain current.jsonl → archive (or read in place on
//                         --dry-run), collapse, fetch sources, emit JSON.
//   weekly  [<since>]     read archive/*.jsonl + current.jsonl (non-destructive),
//                         filter by window (default: latest Friday 13:00 strictly
//                         before today; or the given date/datetime), emit JSON.
//   commit  standup       advance the last-standup marker to now. (weekly: n/a)
//
// Config comes from --config <path>, else $CLAUDE_CONFIG_DIR/worklog-sources.json.
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

function flag(name, dflt) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : dflt;
}
function has(name) {
  return process.argv.includes(name);
}

function loadCfg() {
  const p =
    flag("--config") ||
    path.join(process.env.CLAUDE_CONFIG_DIR || "", "worklog-sources.json");
  const cfg = JSON.parse(fs.readFileSync(p, "utf8"));
  if (!cfg.worklog_dir) throw new Error("worklog_dir missing from " + p);
  return cfg;
}

// ---- record helpers --------------------------------------------------------

function parseJsonl(file) {
  if (!fs.existsSync(file)) return [];
  const out = [];
  for (const line of fs.readFileSync(file, "utf8").split("\n")) {
    if (!line) continue;
    try {
      out.push(JSON.parse(line));
    } catch {
      /* skip a torn line rather than abort the whole report */
    }
  }
  return out;
}

// Collapse per-turn records into one entry per session: the last record holds
// the final title, the count is the activity length. Trivial sessions
// (turns < 2) are counted, not listed. Mirrors the jq the skills used to run.
function collapse(records) {
  const bySession = new Map();
  for (const r of records) {
    const k = r.session || r.ts; // null session → treat each as its own
    (bySession.get(k) || bySession.set(k, []).get(k)).push(r);
  }
  const sessions = [];
  let trivialCount = 0;
  for (const recs of bySession.values()) {
    recs.sort((a, b) => (a.ts < b.ts ? -1 : a.ts > b.ts ? 1 : 0));
    const last = recs[recs.length - 1];
    const entry = {
      session: recs[0].session,
      cwd: last.cwd,
      title: last.title || last.last_prompt,
      turns: recs.length,
      first: recs[0].ts,
      last: last.ts,
    };
    if (entry.turns < 2) trivialCount++;
    else sessions.push(entry);
  }
  sessions.sort((a, b) => (a.first < b.first ? -1 : a.first > b.first ? 1 : 0));
  return { sessions, trivialCount };
}

// ---- window ----------------------------------------------------------------

function localDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

// Latest Friday 13:00 (local) strictly before today: on a Friday this lands on
// the previous week's Friday, giving a full work-week window.
function lastFriday1300() {
  const c = new Date();
  c.setHours(13, 0, 0, 0);
  c.setDate(c.getDate() - 1); // yesterday or earlier — never today
  while (c.getDay() !== 5) c.setDate(c.getDate() - 1);
  return c;
}

function tsCompact(d) {
  // 2026-07-10T13:00:00.000Z → 20260710T130000Z
  return d.toISOString().replace(/[-:]/g, "").replace(/\..+/, "Z");
}

// ---- source fetch ----------------------------------------------------------

function fetchSources(cfg, sinceDate) {
  return (cfg.sources || []).map((s) => {
    const cmd = s.cmd.split("{{since}}").join(sinceDate);
    // instruction (if set) tells the skill how to render this source; passed
    // through untouched so a source carries its own consumption hint.
    const meta = s.instruction ? { instruction: s.instruction } : {};
    try {
      const output = execSync(cmd, {
        encoding: "utf8",
        timeout: 60000,
        stdio: ["ignore", "pipe", "pipe"],
      });
      return { name: s.name, output: output.trimEnd(), ...meta };
    } catch (e) {
      return { name: s.name, output: null, error: String(e.message || e), ...meta };
    }
  });
}

// ---- subcommands -----------------------------------------------------------

function standup(cfg) {
  const dir = cfg.worklog_dir;
  const dry = has("--dry-run");
  const now = new Date();
  const ts = tsCompact(now);
  fs.mkdirSync(path.join(dir, "archive"), { recursive: true });
  fs.mkdirSync(path.join(dir, "reports"), { recursive: true });

  const live = path.join(dir, "current.jsonl");
  let drained = null;
  if (!fs.existsSync(live) || fs.statSync(live).size === 0) {
    drained = null;
  } else if (dry) {
    drained = live; // peek in place, leave it for the next real run
  } else {
    drained = path.join(dir, "archive", ts + ".jsonl");
    fs.renameSync(live, drained); // atomic: a concurrent Stop-hook append lands in a fresh current.jsonl
  }

  const records = drained ? parseJsonl(drained) : [];
  const { sessions, trivialCount } = collapse(records);

  // Source window: last-standup marker, else earliest drained record, else 7d ago.
  const marker = readMarker(dir);
  let start, startSource;
  if (marker) {
    start = marker;
    startSource = "marker";
  } else if (records.length) {
    start = records.map((r) => r.ts).sort()[0];
    startSource = "earliest";
  } else {
    const d = new Date(now);
    d.setDate(d.getDate() - 7);
    start = d.toISOString();
    startSource = "default";
  }
  const startDate = start.slice(0, 10);

  return {
    mode: "standup",
    dry_run: dry,
    empty: !drained,
    window: { start, startDate, source: startSource },
    report_path: dry ? null : path.join(dir, "reports", ts + ".md"),
    latest_report: latestReport(dir),
    sessions,
    trivialCount,
    sources: drained ? fetchSources(cfg, startDate) : [],
  };
}

function weekly(cfg) {
  const dir = cfg.worklog_dir;
  const now = new Date();
  const ts = tsCompact(now);
  fs.mkdirSync(path.join(dir, "weekly"), { recursive: true });

  const arg = firstPositional(3); // after "weekly"
  const startDt = arg ? new Date(arg) : lastFriday1300();
  if (isNaN(startDt)) throw new Error("unparseable since-date: " + arg);
  const start = startDt.toISOString();

  // Union of every archived batch + the live (undrained) file, filtered by ts.
  let records = [];
  const archiveDir = path.join(dir, "archive");
  if (fs.existsSync(archiveDir)) {
    for (const f of fs.readdirSync(archiveDir).filter((f) => f.endsWith(".jsonl")))
      records = records.concat(parseJsonl(path.join(archiveDir, f)));
  }
  records = records.concat(parseJsonl(path.join(dir, "current.jsonl")));
  records = records.filter((r) => r.ts >= start);

  const { sessions, trivialCount } = collapse(records);
  const startDate = localDate(startDt);

  return {
    mode: "weekly",
    window: { start, startDate, end: now.toISOString(), endDate: localDate(now) },
    report_path: path.join(dir, "weekly", ts + ".md"),
    sessions,
    trivialCount,
    sources: fetchSources(cfg, startDate),
  };
}

function commit(cfg) {
  const which = firstPositional(3);
  if (which !== "standup") throw new Error("commit only supports: standup");
  fs.writeFileSync(
    path.join(cfg.worklog_dir, "last-standup"),
    new Date().toISOString() + "\n",
  );
  return { committed: "standup" };
}

// ---- small utilities -------------------------------------------------------

function readMarker(dir) {
  try {
    const m = fs.readFileSync(path.join(dir, "last-standup"), "utf8").trim();
    return m || null;
  } catch {
    return null;
  }
}

function latestReport(dir) {
  const rd = path.join(dir, "reports");
  if (!fs.existsSync(rd)) return null;
  const files = fs
    .readdirSync(rd)
    .filter((f) => f.endsWith(".md"))
    .sort();
  return files.length ? path.join(rd, files[files.length - 1]) : null;
}

// Nth argv token that isn't a flag or a flag's value, counting from `from`.
function firstPositional(from) {
  for (let i = from; i < process.argv.length; i++) {
    const a = process.argv[i];
    if (a === "--config") {
      i++;
      continue;
    }
    if (a.startsWith("--")) continue;
    return a;
  }
  return undefined;
}

function main() {
  const sub = process.argv[2];
  const cfg = loadCfg();
  let result;
  if (sub === "standup") result = standup(cfg);
  else if (sub === "weekly") result = weekly(cfg);
  else if (sub === "commit") result = commit(cfg);
  else throw new Error("usage: worklog-prep <standup|weekly|commit> ...");
  process.stdout.write(JSON.stringify(result, null, 2) + "\n");
}

main();
