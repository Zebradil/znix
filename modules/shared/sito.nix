{ inputs, ... }:
{
  flake-file.inputs.sito = {
    url = "github:Zebradil/sito";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Roaming substituter selection (kasha's deferred "selection shim", now its
  # own project): nix talks only to sito on localhost, and sito routes each
  # request to the best reachable upstream — kasha box on the LAN, remote
  # cache elsewhere, cache.nixos.org as the last tier. Replaces the static
  # list + connect-timeout approach that made off-LAN builds crawl.
  flake.modules.darwin.sito = {
    imports = [ inputs.sito.darwinModules.default ];

    services.sito = {
      enable = true;
      # Determinate owns nix.conf on this platform via
      # determinateNix.customSettings, so the module's nix.settings wiring
      # would be inert; the host's customSettings point substituters at sito
      # instead (see hosts/trv4250).
      manageSubstituters = false;
      settings.tier = [
        {
          upstream = [
            { url = "https://kasha.lan.zebradil.dev"; }
            { url = "https://znix.zebradil.dev"; }
          ];
        }
        {
          upstream = [
            { url = "https://cache.nixos.org"; }
          ];
        }
      ];
    };
  };
}
