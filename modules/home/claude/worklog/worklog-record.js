"use strict";
// worklog Stop hook: append one record per turn to <worklog_dir>/current.jsonl.
// Dumb producer — no gating, no dedup, no LLM. The /standup skill drains and
// processes this file. Never throws: a hook error must not disrupt the session.
//
// argv[2] = path to worklog-sources.json ({ profile, worklog_dir, sources }).
// stdin   = Stop hook payload ({ session_id, transcript_path, cwd, ... }).
const fs = require("fs");
const path = require("path");

function main() {
  const configPath = process.argv[2];
  if (!configPath) return;

  const payload = JSON.parse(fs.readFileSync(0, "utf8"));
  const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const dir = cfg.worklog_dir;
  if (!dir) return;

  // Scan the transcript for the latest ai-title (Claude Code's own one-line
  // session topic) and last user prompt. Both are undocumented internal
  // record types — fall back gracefully, never assume they exist.
  let title = null;
  let lastPrompt = null;
  const transcript = payload.transcript_path;
  if (transcript && fs.existsSync(transcript)) {
    for (const line of fs.readFileSync(transcript, "utf8").split("\n")) {
      if (!line) continue;
      let rec;
      try {
        rec = JSON.parse(line);
      } catch {
        continue;
      }
      if (rec.type === "ai-title" && rec.aiTitle) title = rec.aiTitle;
      else if (rec.type === "last-prompt" && rec.lastPrompt) lastPrompt = rec.lastPrompt;
    }
  }

  const record = {
    ts: new Date().toISOString(),
    session: payload.session_id || null,
    profile: cfg.profile || null,
    cwd: payload.cwd || null,
    title,
    // Truncate: two profiles sharing a worklog append concurrently, and a
    // huge pasted prompt would push the append past the atomic-write size,
    // interleaving lines and corrupting the JSONL the /standup skill parses.
    last_prompt: lastPrompt ? lastPrompt.slice(0, 500) : lastPrompt,
  };

  fs.mkdirSync(dir, { recursive: true });
  fs.appendFileSync(path.join(dir, "current.jsonl"), JSON.stringify(record) + "\n");
}

try {
  main();
} catch {
  // ponytail: swallow everything — a broken worklog write must never break a session.
}
