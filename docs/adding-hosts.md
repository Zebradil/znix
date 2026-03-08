# Adding a New Host

## Steps

1. **Create host directory**: `hosts/<hostname>/default.nix`

2. **Write the flake-parts module** that registers `flake.nixosConfigurations.<hostname>` or `flake.darwinConfigurations.<hostname>`:

```nix
{ inputs, self, ... }:
{
  flake.nixosConfigurations.<hostname> = inputs.nixpkgs.lib.nixosSystem {
    modules =
      (builtins.attrValues self.nixosModules)
      ++ [
        inputs.home-manager.nixosModules.home-manager
        ../../users/<username>
        ({ ... }: {
          networking.hostName = "<hostname>";
          system.stateVersion = "<version>";
          nixpkgs.hostPlatform.system = "<system>";
          znix = {
            # Enable desired features
          };
        })
      ];
    specialArgs = { inherit inputs self; };
  };
}
```

3. **Add hardware config** if NixOS: `hosts/<hostname>/hardware-configuration.nix`

4. **Create or reuse a user** in `users/<username>/`

5. **Add SOPS keys** if the host needs secrets:
   - Derive the age key from the host's SSH ed25519 key: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`
   - Add the key to `.sops.yaml` under `keys.hosts`
   - Add creation rules for the host's secrets

6. **Lock and check**: `nix flake lock && nix flake check`
