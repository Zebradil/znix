{ inputs, self, ... }:
let
  flakeInputs = inputs.nixpkgs.lib.filterAttrs (
    n: v: n != "self" && inputs.nixpkgs.lib.isType "flake" v
  ) inputs;

  common = {
    nixpkgs = {
      config.allowUnfree = true;
      overlays = [ self.overlays.default ];
    };

    nix.settings = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        warn-dirty = false;
        extra-substituters = [ "https://znix.zebradil.dev" ];
        extra-trusted-public-keys = [ "znix.zebradil.dev:nvr0OQFRddbHGopQbyLbLXQnntFBDKp23tqQq+msppw=" ];
      };
      gc = {
        automatic = true;
        dates = "daily";
        options = "--delete-older-than 7d";
      };
    };
  };

  nixosModule =
    { lib, ... }:
    lib.mkMerge [
      common
      {
        nix.settings = {
          settings = {
            auto-optimise-store = lib.mkDefault true;
            flake-registry = "";
            trusted-users = [
              "root"
              "@wheel"
            ];
          };

          registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
          nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
        };
      }
    ];

  darwinModule =
    { config, lib, ... }:
    lib.mkMerge [
      common
      (lib.mkIf config.nix.enable {
        nix.settings.trusted-users = [
          "root"
          "@admin"
        ];
      })
    ];
in
{
  flake.modules.nixos.nix-settings = nixosModule;
  flake.modules.darwin.nix-settings = darwinModule;
}
