---
name: alerts
description: List firing Alertmanager alerts for a named environment (cluster, kubectl context) with `am-alerts`, filtered by severity or any label. Use for "critical alerts in <env>", "what's firing", or before investigating an alert in a cluster.
allowed-tools: Bash(am-alerts *)
---

# alerts

`am-alerts` queries an Alertmanager's `/api/v2/alerts` and prints a compact
summary: a header with the environment, Alertmanager URL, and kubectl context,
then one block per alert, most severe first.

## 1. Resolve the environment

Run `am-alerts --list`. It prints every known environment: name, Alertmanager
URL, kubectl context. Map the user's words to one name; users shorten names
("search-backend-stage" for a longer context name), so match on the
distinctive parts. Done when exactly one name fits. Two or more fit: ask which.
None fits: take an Alertmanager URL from the user, which `am-alerts` accepts in
place of a name.

## 2. Build matchers

Each extra argument is an Alertmanager label matcher; all must hold.

- critical: `severity=critical`
- warnings: `severity=warning`
- critical and warnings: `severity=~"critical|warning"`
- in namespace foo: `namespace=foo`
- about X: `alertname=~".*X.*"`

With no severity asked for, add `alertname!~"Watchdog|InfoInhibitor"`: both are
heartbeats that fire permanently by design.

## 3. Query

```bash
am-alerts <name> [matcher...]
```

- `--all` includes silenced and inhibited alerts (marked `SUPPRESSED`); use it
  when the user asks whether an alert is silenced or why it stopped notifying.
- `--json` returns the raw API response, for fields the summary omits
  (`generatorURL`, `fingerprint`, `receivers`).
- A 400 error quotes the matcher parse failure; fix the matcher and rerun.

## 4. Report

Group alerts by `alertname`: count, severity, how long firing, the labels that
tell instances apart (namespace, pod, job), and the `summary`. Say "no alerts"
plainly when the count is 0.

The header's `kube-context` is the cluster the alerts come from. Every kubectl
command in a follow-up investigation passes `--context <kube-context>`, so the
right cluster is hit whatever the current context is. Investigate with read-only
commands (`get`, `describe`, `logs`, `top`, `events`) unless the user asks for a
change.
