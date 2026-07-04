# znix

A unified Nix configuration (dendritic pattern via flake-parts) for personal and work
hosts.

The net-local binary-cache product (box + remote cache design, eager bidirectional
replication, root-manifest discovery) has moved to
[`kasha`](https://github.com/Zebradil/kasha) — see its `CONTEXT.md` for that
terminology. znix remains kasha's reference consumer/deployment: its remote cache is
`znix.zebradil.dev`, backed by Cloudflare R2.
