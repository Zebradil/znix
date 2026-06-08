{ inputs, ... }:
{
  flake-file.inputs = {
    # Pinned to the last known-good nixpkgs-unstable rev before the 26.11 /
    # GDM 50 jump that broke the Wayland greeter on tuxedo
    # (gdm-wayland-session: "Unable to run session" -> GDM gives up -> black
    # screen). Scoped to this host so other hosts (darwin) stay on unstable.
    # Drop once upstream ships a fix for GDM 50 / gnome-shell greeter and let
    # tuxedo follow the global nixpkgs again.
    nixpkgs-tuxedo.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  flake.nixosConfigurations = inputs.self.lib.mkNixos "x86_64-linux" "tuxedo" {
    nixpkgs = inputs.nixpkgs-tuxedo;
  };
  flake.nixosSystemMap.tuxedo = "x86_64-linux";
}
