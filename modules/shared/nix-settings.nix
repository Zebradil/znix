{ inputs, self, ... }:
let
  flakeInputs = inputs.nixpkgs.lib.filterAttrs
    (n: v: n != "self" && inputs.nixpkgs.lib.isType "flake" v)
    inputs;

  nixosModule =
    { lib, ... }:
    {
      nix.settings = {
        trusted-users = [
          "root"
          "@wheel"
        ];
        auto-optimise-store = lib.mkDefault true;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        warn-dirty = false;
        flake-registry = "";
      };

      nix.gc = {
        automatic = true;
        dates = "daily";
        options = "--delete-older-than 7d";
      };

      nix.registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
      nix.nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [ self.overlays.default ];
    };

  darwinModule =
    { config, lib, ... }:
    {
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [ self.overlays.default ];

      nix.settings = lib.mkIf config.nix.enable {
        trusted-users = [
          "root"
          "@admin"
        ];
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        warn-dirty = false;
      };

      nix.gc = lib.mkIf config.nix.enable {
        automatic = true;
        options = "--delete-older-than 7d";
      };
    };
in
{
  flake.modules.nixos.nix-settings = nixosModule;
  flake.modules.darwin.nix-settings = darwinModule;
}
