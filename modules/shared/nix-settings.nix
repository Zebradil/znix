{ inputs, self, ... }:
let
  # "nixpkgs" is intentionally excluded: each NixOS system already
  # self-registers its own nixpkgs flake (nixpkgs-flake.nix). Overriding it
  # here would conflict for hosts that pin a different nixpkgs (e.g. tuxedo),
  # and the self-registered value is the correct one anyway.
  flakeInputs = inputs.nixpkgs.lib.filterAttrs (
    n: v: n != "self" && n != "nixpkgs" && inputs.nixpkgs.lib.isType "flake" v
  ) inputs;

  # Shared nix settings values, reusable across platforms
  nixSettings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
    # Full list (not extra-substituters): Determinate writes nix.custom.conf
    # alphabetically, placing any extra-substituters above its own plain
    # `substituters = cache.nixos.org`, which then overwrites the list and drops
    # our caches. A plain substituters assignment has no such ordering hazard.
    substituters = [
      "https://cache.nixos.org/"
      "https://znix.zebradil.dev"
      # kasha net-local box (LAN 192.168.0.100). priority=10 beats
      # cache.nixos.org (40) and the box's advertised 50, so it wins for paths
      # it holds; misses fall through to the other caches. Off-LAN it fails
      # within connect-timeout below.
      "https://kasha.lan.zebradil.dev?priority=10"
    ];
    # Full list (not extra-trusted-public-keys), same reason as substituters
    # above: Determinate writes nix.custom.conf alphabetically, so a plain
    # `trusted-public-keys = cache.nixos.org` line lands *after* any
    # `extra-trusted-public-keys` and resets the list, dropping our keys — then
    # every znix-signed path fails require-sigs and gets rebuilt. A plain
    # assignment merges into that single line instead. cache.nixos.org is kept
    # explicitly so replacing the built-in default loses nothing.
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "znix.zebradil.dev:nvr0OQFRddbHGopQbyLbLXQnntFBDKp23tqQq+msppw="
      "fluffy-nix-cache-01-1:i+jKT07GaI6rxKCct/m+NnHQyinTXc0V67WnHMrhjps="
    ];
    # Bounds the off-LAN tax: the box connection fails this fast on roaming
    # hosts before nix tries the next substituter.
    connect-timeout = 5;
  };

  nixosModule =
    { config, lib, ... }:
    let
      usingDeterminate = config.determinate.enable or false;
    in
    {
      nixpkgs = {
        config.allowUnfree = true;
        overlays = [ self.overlays.default ];
      };

      nix = lib.mkMerge [
        {
          # Always pin flake registry and nixPath regardless of Nix manager
          registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
          nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
        }
        {
          # Always apply cache settings: on Determinate NixOS, nix.settings routes
          # to /etc/nix/nix.custom.conf which is included by Determinate Nixd.
          settings = {
            inherit (nixSettings)
              substituters
              trusted-public-keys
              connect-timeout
              warn-dirty
              ;
          };
        }
        (lib.mkIf (!usingDeterminate) {
          enable = true;
          settings = {
            inherit (nixSettings) experimental-features;
            auto-optimise-store = lib.mkDefault true;
            flake-registry = "";
            trusted-users = [
              "root"
              "@wheel"
            ];
          };
          gc = {
            automatic = true;
            options = "--delete-older-than 7d";
          };
        })
      ];
    };

  # Determinate Nix manages nix.enable/settings/gc on both Darwin and NixOS
  darwinModule = {
    nixpkgs = {
      config.allowUnfree = true;
      overlays = [ self.overlays.default ];
    };

    # Cache settings (Determinate routes nix.settings to nix.custom.conf).
    # trusted-public-keys is required, not optional: the box and remote serve
    # znix-signed paths, which fail verification without the key trusted.
    nix.settings = {
      inherit (nixSettings) substituters trusted-public-keys connect-timeout;
    };
  };
in
{
  flake.lib.nixSettings = nixSettings;
  flake.modules.nixos.nix-settings = nixosModule;
  flake.modules.darwin.nix-settings = darwinModule;
}
