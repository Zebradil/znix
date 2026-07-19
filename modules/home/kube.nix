{ inputs, ... }:
{
  flake.modules.homeManager.kube =
    { config, lib, ... }:
    let
      cfg = config.znix.kube.homelab;
      ph = config.sops.placeholder;

      endpoints = {
        homelab = "https://k8s.junior.zebradil.dev:6443";
        homelab-lan = "https://k8s.junior.lan.zebradil.dev:6443";
        homelab-ts = "https://k8s.junior.ts.zebradil.dev:6443";
      };

      mkCluster = name: url: {
        inherit name;
        cluster = {
          server = url;
          "certificate-authority-data" = ph."ca";
        };
      };

      mkContext = name: _: {
        inherit name;
        context = {
          cluster = name;
          user = "homelab";
        };
      };

      kubeconfig = {
        apiVersion = "v1";
        kind = "Config";
        clusters = lib.mapAttrsToList mkCluster endpoints;
        users = [
          {
            name = "homelab";
            user = {
              "client-certificate-data" = ph."client-cert";
              "client-key-data" = ph."client-key";
            };
          }
        ];
        contexts = lib.mapAttrsToList mkContext endpoints;
      };
    in
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      options.znix.kube.homelab.enable =
        lib.mkEnableOption "sops-rendered homelab kubeconfig in ~/.kube/custom.clusters";

      config = lib.mkIf cfg.enable {
        sops = {
          defaultSopsFile = ../../secrets/homelab-kube.yaml;
          age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

          secrets = {
            "ca" = { };
            "client-cert" = { };
            "client-key" = { };
          };

          templates."homelab.yaml" = {
            path = "${config.home.homeDirectory}/.kube/custom.clusters/homelab.yaml";
            mode = "0400";
            content = builtins.toJSON kubeconfig;
          };
        };
      };
    };
}
