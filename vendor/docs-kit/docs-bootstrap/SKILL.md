---
name: docs-bootstrap
description: Set up docs-kit in a project (docs/ skeleton, site.yaml, generated CLI reference, docs workflow, Renovate), prove it with a local build, and open a PR. Use when asked to bootstrap docs, set up a docs site, or add docs-kit to this project, or to close a docs-audit gap with fix-by docs-bootstrap.
---

# docs-bootstrap

Add docs-kit to the consuming project (the current repository) and open one PR. Terms (consuming project, content contract, refgen) are those of the kit's [`CONTEXT.md`](../../CONTEXT.md).

Every step is **fill-only**: it creates what is missing and leaves what exists byte-identical, whether a file, a `site.yaml` field or comment, or a page. A second run on a bootstrapped project therefore ends with no commit and no PR; say so and stop.

`docs/` holding another site generator (a `package.json` without `@zebradil/starlight-kit`, `mkdocs.yml`, `book.toml`, a Docusaurus config): stop and ask the owner. Unrelated files in `docs/` (ADRs, notes) stay where they are.

## 1. Worktree and kit ref

Work in a git worktree on a feature branch, following the project's `AGENTS.md`/`CLAUDE.md`; default branch name `docs/bootstrap`. Paths below are relative to the worktree root.

`REF`, the kit version, in this order:

1. The ref in an existing `docs/package.json` (`github:Zebradil/docs-kit#<REF>`).
2. A tag or commit SHA the user named.
3. The latest release tag:
   ```sh
   gh api --paginate repos/Zebradil/docs-kit/tags --jq '.[].name' | grep -E '^v[0-9]' | sort -V | tail -1
   ```

No ref from any of the three: stop and reply "docs-kit has no release tag yet: push `vX.Y.Z` in Zebradil/docs-kit, or rerun naming a commit SHA to pin". A SHA pin goes into the PR as an owner-review item: Renovate skips a bare SHA in `uses:` (`unversioned-reference`), so it has to become a tag before bumps work.

## 2. Skeleton

Create each missing file:

| File | Content |
|---|---|
| `docs/package.json` | `{ "private": true, "type": "module", "scripts": { "build": "astro build" }, "dependencies": { "@zebradil/starlight-kit": "github:Zebradil/docs-kit#<REF>" } }`, formatted |
| `docs/astro.config.mjs` | `import docsKit from '@zebradil/starlight-kit';` blank line `export default docsKit({ site: 'site.yaml' });` |
| `docs/src/content.config.mjs` | `export { collections } from '@zebradil/starlight-kit/content';` |
| `docs/.gitignore` | `node_modules/`, `dist/`, `.astro/`, one per line |
| `docs/src/content/docs/getting-started.md` | Only when no `getting-started.md`/`.mdx` exists (the build fails without one): front matter `title: Getting started` and a one-line `description`, body a `:::note` saying it is a placeholder for docs-write |

Install from `docs/`: `npm ci` when `package-lock.json` exists, `npm install` otherwise (it writes the lock). The kit then sits in `docs/node_modules/@zebradil/starlight-kit`, with the schema, validator and `help2md` of exactly `REF`.

## 3. site.yaml

Missing: write `docs/site.yaml`, first line `# yaml-language-server: $schema=node_modules/@zebradil/starlight-kit/schema/site.schema.json`. Present: add only the fields the validator reports missing.

Field sources, first hit wins. `docs/.audit.md` with a `fix-by: docs-bootstrap` gap carries draft values in its evidence; take them, rechecked against the sources below.

| Field | Sources |
|---|---|
| `name` | Binary name: Cargo `[[bin]] name` or `[package] name`, the Go `cmd/<name>` or module's last segment |
| `tagline` | README's first paragraph, Cargo `description`; one sentence, at most 160 chars |
| `repo` | `gh repo view --json url -q .url`; else Cargo `repository`, `go.mod` module path, GitHub links in README or CHANGELOG |
| `theme` | `default` |
| `logo` | An SVG logo already in the repository, copied to `docs/src/assets/`; omit when there is none |
| `install` | README's own order. Only commands that install without secrets or config: `docker pull <image>` rather than a `docker run` needing env, `nix profile install github:<owner>/<repo>` when the flake has `packages.default`, `cargo install <crate>` only when the crate is on crates.io (`curl -s https://crates.io/api/v1/crates/<crate>`), else `cargo install --git <repo>`, `go install <module>/<main pkg>@latest`, Homebrew from goreleaser `brews` |
| `headline`, `eyebrow`, `description` | Optional. README's opening: a headline no longer than the tagline, a category label, a one-to-three sentence lede; omit when the README has none |
| `features` | 3 to 6 from README capability claims, each backed by code |
| `flow` | Optional. Only connections the README or code states: who pushes to or reads from the project, what it syncs with; omit otherwise |
| `components` | Optional. Binaries, subcommands, modules and packages the project ships, from the build files |
| `links` | `CHANGELOG.md`, docs.rs or pkg.go.dev when the project ships a library |
| `reference.cli` | Step 4 |

A value not copied verbatim from a source, or a command not run, is **guessed**: end its line with `# guessed: <source and why>`. The PR lists every guessed value for the owner.

Done when, from `docs/`, `node node_modules/@zebradil/starlight-kit/schema/validate.mjs site.yaml` prints `site.yaml: ok`.

## 4. CLI reference

Skip when the project ships no CLI. The kit's workflow runs `reference.cli.build` from the repository root, then `help2md` on `path`:

| Project | `build` | `path` |
|---|---|---|
| `Cargo.toml` at the root | `cargo build --release` (`-p <crate>` in a workspace) | `target/release/<bin>` |
| `go.mod` at the root | `go build -o bin/<bin> ./cmd/<bin>` (or `.`) | `bin/<bin>` |
| Builds only with Nix | `nix build .#<package>` | `result/bin/<bin>`, and the workflow gets `with: { nix: true }` |

`help2md` is the only generator the workflow regenerates and checks. When the project already depends on clap-markdown or cobra's `doc` package, name it in the PR as a candidate for a richer reference; `reference.cli` stays on help2md.

Run `build` from the root as written, wrapped in `nix develop -c` when the host lacks the toolchain and the flake has a devShell. Then from `docs/`:

```sh
npx --no-install help2md --bin ../<path> --out src/content/docs/reference/cli
```

Done when `git status --porcelain` lists nothing outside `docs/`; add untracked build output (such as `/bin/`) to the root `.gitignore`.

## 5. Workflow

Skip when a workflow already calls `Zebradil/docs-kit/.github/workflows/docs.yml`. Otherwise write `.github/workflows/docs.yml`, `<default branch>` from `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` or `git symbolic-ref refs/remotes/origin/HEAD`:

```yaml
name: docs
on:
  push: { branches: [<default branch>] }
  pull_request:
permissions: { contents: read, pages: write, id-token: write }
jobs:
  docs:
    uses: Zebradil/docs-kit/.github/workflows/docs.yml@<REF>
```

Keep `uses:` on its own line: Renovate reads it line by line and misses a flow mapping. Match the ref style of the project's other `uses:` lines: when they pin digests, write `@<sha> # <REF>` with the sha from `gh api repos/Zebradil/docs-kit/commits/<REF> --jq .sha`. The project lints workflows (actionlint in flake checks, pre-commit, CI): run that linter on the new file.

## 6. Renovate

Skip when the project has no Renovate config (`renovate.json(5)`, `.github/renovate.json(5)`, `.renovaterc*`, `renovate` in the root `package.json`); name that in the PR, since nothing then bumps the kit. Renovate's default managers already track both pins as the package `Zebradil/docs-kit` on the `github-tags` datasource: npm reads `docs/package.json`, github-actions reads the workflow's `uses:`. When the config sets `enabledManagers`, add `npm` and `github-actions` to it.

Append one rule as the last `packageRules` entry, so it wins over an existing github-actions group, unless a rule already matches `Zebradil/docs-kit`:

```json5
// docs/package.json and .github/workflows/docs.yml pin the same docs-kit tag: the workflow
// runs the help2md the package installs. Last, so it wins over other groups.
{ description: "Bump the docs-kit package and its reusable workflow together", matchPackageNames: ["Zebradil/docs-kit"], groupName: "docs-kit" },
```

Validate: `npx --yes --package renovate -- renovate-config-validator <config file>`.

## 7. Verify and ship

Done when, in the worktree:

- from `docs/`, after `rm -rf node_modules dist .astro`: `npm ci && npx --no-install astro build` ends with `Complete!`;
- refgen from step 4 leaves `git status` clean after its pages are committed;
- `docs/.audit.md` has a `fix-by: docs-bootstrap` gap: it is `status: resolved` with `- resolution: branch <branch>`, so docs-write can take the page gaps that depend on it. Tracked by git: commit it with the skeleton; untracked: edit the main checkout's copy after opening the PR.

Commit in small steps, Conventional Commits unless the project says otherwise: skeleton and `site.yaml`; generated reference; workflow; Renovate. Push and open a PR with `gh pr create`:

- **What / Why**: files added, the pinned `REF`.
- **Owner review**: every guessed `site.yaml` value; a SHA pin to replace with a tag.
- **Owner step**: enable GitHub Pages with source GitHub Actions (Settings → Pages → Build and deployment → Source), or `gh api --method POST repos/<owner>/<repo>/pages -f build_type=workflow`. Until then the deploy job on the default branch fails. Leave repository settings to the owner.
- `Closes #<n>` when the bootstrap gap has an `issue`.

Reply with the PR URL, the guessed values, and the owner step.
