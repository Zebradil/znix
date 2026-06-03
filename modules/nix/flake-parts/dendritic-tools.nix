{ inputs, ... }:
{
  # setup of tools for dendritic pattern

  # Simplify Nix Flakes with the module system
  # https://github.com/hercules-ci/flake-parts

  # Generate flake.nix from module options.
  # https://github.com/vic/flake-file

  # Import all nix files in a directory tree.
  # https://github.com/vic/import-tree

  flake-file.inputs = {
    # Temporarily pinned to the last known-good nixpkgs-unstable rev
    # before the 26.11 / GDM 50 jump that broke the Wayland greeter on
    # tuxedo (gdm-wayland-session: "Unable to run session" -> GDM gives
    # up -> black screen). Revert to "nixpkgs-unstable" once upstream
    # ships a fix for GDM 50 / gnome-shell greeter.
    nixpkgs.url = "github:NixOS/nixpkgs/d233902339c02a9c334e7e593de68855ad26c4cb";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-file.url = "github:vic/flake-file";
    import-tree.url = "github:vic/import-tree";
  };

  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.flake-file.flakeModules.default
  ];

  # import all modules recursively with import-tree
  flake-file.outputs = ''
    inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules)
  '';

  systems = [
    "aarch64-darwin"
    "x86_64-linux"
  ];
}
