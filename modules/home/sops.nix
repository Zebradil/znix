{ inputs, ... }:
{
  # Shared home-manager sops wiring. Any home module that renders a sops secret
  # or template (kube, docker registry auth, ...) relies on this being imported
  # once — sops.age.keyFile is single-valued, so it must not be set per-module.
  flake.modules.homeManager.sops =
    { config, ... }:
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    };
}
