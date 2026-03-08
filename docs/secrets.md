# Secrets Management

## Overview

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using age keys derived from SSH ed25519 host keys.

## Key Hierarchy

- **User key** (`zebradil`): Personal age key for encrypting/decrypting all secrets
- **Host keys**: Derived from each host's `/etc/ssh/ssh_host_ed25519_key`

## Deriving a Host Age Key

```bash
# From the host's public key
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub

# Or from a private key (for initial setup)
ssh-to-age -private-key < /etc/ssh/ssh_host_ed25519_key
```

## Creating/Editing Secrets

```bash
# Edit user secrets
sops secrets/users/zebradil.yaml

# Edit shared host secrets (wireless PSK, etc.)
sops secrets/hosts/common.yaml

# Edit host-specific secrets
sops secrets/hosts/tuxedo/ssh_host_ed25519.key
```

## Bootstrapping a New Host

1. Generate SSH host key on the target machine or via nixos-anywhere's `--extra-files`
2. Derive the age public key: `ssh-to-age < ssh_host_ed25519_key.pub`
3. Add the key to `.sops.yaml`
4. Re-encrypt existing secrets: `sops updatekeys secrets/path/to/file.yaml`
5. Deploy with `nixos-rebuild switch --flake .#<hostname>`

## Secret Paths

| Path | Contents |
|------|----------|
| `secrets/users/zebradil.yaml` | `password`, `u2f_keys/*` |
| `secrets/hosts/common.yaml` | `wireless` (PSK) |
| `secrets/hosts/tuxedo/ssh_host_ed25519.key` | Host SSH private key |
