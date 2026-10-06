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

  # sito keeps no history, so its /metrics go to the homelab VictoriaMetrics
  # through the cluster vmagent's tailnet ingress — reachable on and off the
  # LAN. That vmagent fans out to vmks (30d retention), which bounds how long
  # an offline laptop's queue is still worth sending.
  remoteWriteUrl = "https://vmagent.lan.zebradil.dev/api/v1/write";
  scrapeInterval = "10s";
  maxDiskUsage = "1GB";
  # Every host scrapes sito at the same localhost address, so without this
  # label all hosts' series collide.
  hostLabel = hostName: "-remoteWrite.label=host=${hostName}";
in
{
  flake-file.inputs.sito.url = "github:Zebradil/sito";

  flake.modules.darwin.sito =
    { config, ... }:
    {
      imports = [ inputs.sito.darwinModules.default ];
      services.sito = service // {
        vmagent = {
          enable = true;
          inherit remoteWriteUrl scrapeInterval maxDiskUsage;
          extraArgs = [ (hostLabel config.networking.hostName) ];
        };
      };
      assertions = [
        {
          assertion = config.networking.hostName != null;
          message = "sito: set networking.hostName, it labels the shipped metrics.";
        }
      ];
    };

  flake.modules.nixos.sito =
    { config, ... }:
    {
      imports = [ inputs.sito.nixosModules.default ];
      services.sito = service;

      # sito's own vmagent options are darwin-only; NixOS has a stock module.
      services.vmagent = {
        enable = true;
        remoteWrite.url = remoteWriteUrl;
        prometheusConfig.scrape_configs = [
          {
            job_name = "sito";
            scrape_interval = scrapeInterval;
            static_configs = [ { targets = [ (config.services.sito.settings.listen or "127.0.0.1:5001") ]; } ];
          }
        ];
        extraArgs = [
          (hostLabel config.networking.hostName)
          "-remoteWrite.maxDiskUsagePerURL=${maxDiskUsage}"
          # The default listens on every interface; its pages are for this host only.
          "-httpListenAddr=127.0.0.1:8429"
        ];
      };
    };
}
