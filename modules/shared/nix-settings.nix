{ inputs, self, ... }:
let
  flakeInputs = inputs.nixpkgs.lib.filterAttrs (
    n: v: n != "self" && inputs.nixpkgs.lib.isType "flake" v
  ) inputs;

  # Shared nix settings values, reusable across platforms
  nixSettings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
    extra-substituters = [ "https://znix.zebradil.dev" ];
    extra-trusted-public-keys = [ "znix.zebradil.dev:nvr0OQFRddbHGopQbyLbLXQnntFBDKp23tqQq+msppw=" ];
  };

  nixosModule =
    { lib, ... }:
    {
      nixpkgs = {
        config.allowUnfree = true;
        overlays = [ self.overlays.default ];
      };

      nix = {
        enable = true;
        settings = nixSettings // {
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

        registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
        nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
      };
    };

  # Darwin uses Determinate Nix — nix.enable/settings/gc are managed by it
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
