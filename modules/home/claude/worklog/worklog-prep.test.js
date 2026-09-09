"use strict";
const assert = require("assert");
const { execFileSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const dir = fs.mkdtempSync(path.join(os.tmpdir(), "worklog-prep-"));
try {
  const archive = path.join(dir, "archive");
  fs.mkdirSync(archive);
  const marker = new Date(Date.now() - 60_000).toISOString();
  const duplicate = { session: "old", ts: "2026-09-01T00:00:00.000Z", title: "old" };
  const current = { session: "current", ts: new Date().toISOString(), title: "current" };
  fs.writeFileSync(path.join(dir, "last-standup"), marker + "\n");
  fs.writeFileSync(path.join(archive, "20000101T000000Z.jsonl"), JSON.stringify(duplicate) + "\n");
  fs.writeFileSync(
    path.join(dir, "current.jsonl"),
    `${JSON.stringify(duplicate)}\n${JSON.stringify(current)}\n${JSON.stringify(current)}\n`,
  );
  const config = path.join(dir, "config.json");
  fs.writeFileSync(config, JSON.stringify({ worklog_dir: dir }));

  const report = JSON.parse(
    execFileSync(process.execPath, [path.join(__dirname, "worklog-prep.js"), "--config", config, "standup"], {
      encoding: "utf8",
    }),
  );
  assert.deepStrictEqual(report.sessions.map(({ session }) => session), ["current"], JSON.stringify(report));
  assert.strictEqual(report.trivialCount, 0, JSON.stringify(report));
} finally {
  fs.rmSync(dir, { recursive: true, force: true });
}
