_: {
  flake.modules.nixos.cloudflare-dynamic-dns =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.znix.cloudflareDynamicDns;

      configType = lib.types.submodule {
        options = {
          domains = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Domain names to point at the selected address.";
          };
          iface = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Network interface to read the address from. Mutually exclusive with `ipcmd`.";
          };
          ipcmd = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Shell command emitting the address. Mutually exclusive with `iface`.";
          };
          stack = lib.mkOption {
            type = lib.types.enum [
              "ipv4"
              "ipv6"
            ];
            default = "ipv6";
            description = "Address family to publish (A vs AAAA).";
          };
          multihost = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Share this domain across hosts (round-robin). Requires a host-id.";
          };
          proxy = lib.mkOption {
            type = lib.types.enum [
              "enabled"
              "disabled"
              "auto"
            ];
            default = "disabled";
            description = "Cloudflare proxy state for the records.";
          };
        };
      };

      # JSON is valid YAML, so build an attrset and serialize instead of
      # hand-assembling indented text.
      mkConfigJson =
        c:
        builtins.toJSON (
          lib.filterAttrs (_: v: v != null) {
            token = config.sops.placeholder.cloudflare-dynamic-dns-token;
            host-id = if c.multihost then cfg.hostId else null;
            inherit (c) iface;
            inherit (c) ipcmd;
            inherit (c) stack;
            inherit (c) proxy;
            inherit (c) multihost;
            inherit (c) domains;
          }
        );

      configFile = name: "/etc/cloudflare-dynamic-dns/config.d/${name}.yaml";
    in
    {
      options.znix.cloudflareDynamicDns = {
        enable = lib.mkEnableOption "cloudflare-dynamic-dns updater";

        package = lib.mkPackageOption pkgs "cloudflare-dynamic-dns" { };

        tokenSopsFile = lib.mkOption {
          type = lib.types.path;
          default = ../../secrets/hosts/k3s.yaml;
          description = "sops file holding the `cloudflare-dynamic-dns-token` key.";
        };

        hostId = lib.mkOption {
          type = lib.types.str;
          default = config.networking.hostName;
          description = "Unique host identifier used by multihost configs.";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "5m";
          description = "Timer period (systemd OnUnitActiveSec) between updates.";
        };

        configs = lib.mkOption {
          type = lib.types.attrsOf configType;
          default = { };
          description = "Named update configs, one file under config.d/ each.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = lib.mapAttrsToList (name: c: {
          assertion = (c.iface != null) != (c.ipcmd != null);
          message = "znix.cloudflareDynamicDns.configs.${name}: set exactly one of `iface` or `ipcmd`.";
        }) cfg.configs;

        sops.secrets.cloudflare-dynamic-dns-token.sopsFile = cfg.tokenSopsFile;

        sops.templates = lib.mapAttrs' (
          name: c:
          lib.nameValuePair "cloudflare-dynamic-dns-${name}.yaml" {
            path = configFile name;
            mode = "0600";
            content = mkConfigJson c;
          }
        ) cfg.configs;

        systemd.services = lib.mapAttrs' (
          name: _c:
          lib.nameValuePair "cloudflare-dynamic-dns-${name}" {
            description = "cloudflare-dynamic-dns update: ${name}";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${lib.getExe cfg.package} --config ${configFile name}";
            };
          }
        ) cfg.configs;

        systemd.timers = lib.mapAttrs' (
          name: _c:
          lib.nameValuePair "cloudflare-dynamic-dns-${name}" {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "1m";
              OnUnitActiveSec = cfg.interval;
              Unit = "cloudflare-dynamic-dns-${name}.service";
            };
          }
        ) cfg.configs;
      };
    };
}
