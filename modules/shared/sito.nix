{ inputs, ... }:
let
  # Roaming substituter selection (kasha's deferred "selection shim", now its
  # own project): nix talks only to sito on localhost, and sito routes each
  # request to the best reachable upstream — kasha box on the LAN, remote
  # cache elsewhere, cache.nixos.org as the last tier. Replaces the static
  # list + connect-timeout approach that made off-LAN builds crawl.
  #
  # Named so a host can add an upstream to an existing tier, e.g.
  # services.sito.tiers.private.upstreams.<name>.url = "...".
  tiers = {
    private = {
      priority = 10;
      upstreams = {
        kasha = {
          priority = 10;
          url = "https://kasha.lan.zebradil.dev";
        };
        znix = {
          priority = 20;
          url = "https://znix.zebradil.dev";
        };
      };
    };
    public = {
      priority = 20;
      upstreams.nixos.url = "https://cache.nixos.org";
    };
  };

  # Determinate owns nix.conf on both platforms, so the module's own
  # nix.settings wiring would be inert (darwin) or fight the shared static
  # list (nixos); each host points its substituters at sito instead.
  service = {
    enable = true;
    manageSubstituters = false;
    inherit tiers;
  };
in
{
  flake-file.inputs.sito = {
    url = "github:Zebradil/sito";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.darwin.sito = {
    imports = [ inputs.sito.darwinModules.default ];
    services.sito = service;
  };

  flake.modules.nixos.sito = {
    imports = [ inputs.sito.nixosModules.default ];
    services.sito = service;
  };
}
