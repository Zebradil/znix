#!/usr/bin/env node
// caveman — Claude Code SubagentStart hook (znix-owned).
//
// SessionStart context reaches the parent thread only, never subagents, so
// Task-spawned agents run caveman-unaware and reply verbose. Upstream caveman
// ships no subagent hook; this mirrors ponytail-subagent.js.
//
// Not vendored under vendor/caveman/ — that tree is a vendir mirror of
// JuliusBrussee/caveman and `vendir sync` would wipe an added file. Lives beside
// the vendored hooks at $CLAUDE_CONFIG_DIR/hooks/ so relative paths still match:
// caveman-activate.js reads the ruleset (SKILL.md + flag) and writes it to
// stdout, so re-run it and wrap that output in the JSON form SubagentStart
// requires (raw stdout is dropped for this event).

const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { readFlag } = require('./caveman-config');

// The .caveman-active flag is the live runtime state (activate.js writes it,
// unlinks on off) — getDefaultMode() would only report the configured default
// and leak the ruleset into subagents even after `stop caveman`. Flag lives in
// the Claude config dir, same resolution as caveman-activate.js.
const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
const mode = readFlag(path.join(claudeDir, '.caveman-active'));
if (!mode || mode === 'off') process.exit(0);

try {
  const ruleset = execFileSync(
    process.execPath,
    [path.join(__dirname, 'caveman-activate.js')],
    { encoding: 'utf8' }
  );
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: 'SubagentStart', additionalContext: ruleset },
  }));
} catch (e) {
  // Silent fail — a hook error must never block subagent start.
}
