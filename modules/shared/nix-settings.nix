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
    extra-substituters = [ "https://znix.zebradil.dev" ];
    extra-trusted-public-keys = [
      "znix.zebradil.dev:nvr0OQFRddbHGopQbyLbLXQnntFBDKp23tqQq+msppw="
      "fluffy-nix-cache-01-1:i+jKT07GaI6rxKCct/m+NnHQyinTXc0V67WnHMrhjps="
    ];
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
            inherit (nixSettings) extra-substituters extra-trusted-public-keys;
          };
        }
        (lib.mkIf (!usingDeterminate) {
          enable = true;
          settings = {
            inherit (nixSettings) experimental-features warn-dirty;
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
  };
in
{
  flake.lib.nixSettings = nixSettings;
  flake.modules.nixos.nix-settings = nixosModule;
  flake.modules.darwin.nix-settings = darwinModule;
}
