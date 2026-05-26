# znixctl follow-ups

## Next migrations (priority order)

- [ ] Port `_process_pool` from `modules/home/shell/zsh/zshrc/tools/gke.zsh` → `znixctl process-pool` (the function that
      triggered the prod incident; subshell + `set -e` suppression bug)
  - Needs: gcloud node-pool ops, taint computation, Slack notification integration
  - Decision: keep Slack call as shell-out to existing `z:slack:post` or port that too?
- [ ] Port `assets/bin/kubectl-ssh` → `znixctl kubectl-ssh` (120 lines, ephemeral busybox pod)
- [ ] Port `assets/bin/vid` → `znixctl vid` (ffmpeg wrapper, 145 lines) — low priority, no error-handling pain
- [ ] Evaluate porting other large zsh tools: `k8s.zsh` (203 lines), `gke.zsh` rest (455 lines total)

## Technical improvements

- [ ] Replace shell-out to `kubectl` with `client-go` once 2-3 commands share the surface (signal snapshot, drain, get
      node — all benefit)
- [ ] Replace shell-out to `gcloud` with GCP Go SDK (`compute/v1`) for MIG ops
- [ ] Add unit tests for `migGroup`, `readNodes`, signal-parse edge cases
- [ ] Add integration test harness using `envtest` or kind for drain logic
- [ ] Structured logging (slog) — keep ANSI prefixes but also support `--log-format=json` for CI

## Build pipeline

- [ ] CI workflow: `nix build .#znixctl` + `go test ./...` on PRs
- [ ] Bump strategy for `vendorHash` — document in `tools/znixctl/README.md`
- [ ] Cross-compile check: `nix build .#znixctl --system x86_64-linux` for colleagues on Linux

## Sharing with colleagues

- [ ] Extract `tools/znixctl/` to standalone repo + flake (mirror `gke-kubeconfiger` pattern)
  - Pull as flake input from znix; overlay shape identical
  - Defer until ≥3 subcommands ported and API stable
- [ ] Write `tools/znixctl/README.md` with usage, build instructions, contribution guide

## Known gotchas

- `internal/tty/tty.go::readLoop` uses raw `unix.Read`; closing the fd via
  `t.f.Close()` does NOT reliably unblock a thread blocked in `read(2)` on a
  tty on macOS (`// unblocks readLoop` comment is incorrect). The hang is
  avoided by opening tty once per command (not per loop iteration), so the
  close-while-read condition never occurs. A proper fix would use kqueue, a
  self-pipe, or the runtime pollster to make Close actually interrupt the read.

- `vendorHash` must be regenerated when go.mod deps change (bootstrap with `lib.fakeHash`, copy from nix build error)
- `home.file.".local/bin"` recursive symlink + explicit `.local/bin/drain-nodes` entry coexist because the old script
  was deleted; adding new compat symlinks for future ports follows the same pattern
- Basename dispatch in `main.go` uses an allow-list (`basenameSubcommands`) — add new entries when adding symlinks
