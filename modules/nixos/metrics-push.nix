_: {
  # Push, not pull: a laptop sleeps and roams, so a central scrape would only
  # see gaps. vmagent queues samples on disk while the homelab is unreachable
  # and replays them with their original timestamps once it is back. The
  # ingress forwards to vmks (30d retention), which bounds how long a queued
  # sample is still worth sending.
  #
  # Other modules add their own jobs to
  # services.vmagent.prometheusConfig.scrape_configs.
  flake.modules.nixos.metrics-push =
    { config, ... }:
    {
      services.prometheus.exporters.node = {
        enable = true;
        # vmagent on this host is the only consumer.
        listenAddress = "127.0.0.1";
        # Failed units after an unattended deploy are the main thing to see.
        enabledCollectors = [ "systemd" ];
      };

      services.vmagent = {
        enable = true;
        remoteWrite.url = "https://vmagent.lan.zebradil.dev/api/v1/write";
        prometheusConfig.scrape_configs = [
          {
            job_name = "node";
            scrape_interval = "30s";
            static_configs = [
              { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
            ];
          }
        ];
        extraArgs = [
          # Every host scrapes the same localhost targets, so without this
          # label all hosts' series collide.
          "-remoteWrite.label=host=${config.networking.hostName}"
          "-remoteWrite.maxDiskUsagePerURL=1GB"
          # The default listens on every interface; its pages are for this host only.
          "-httpListenAddr=127.0.0.1:8429"
        ];
      };
    };
}
