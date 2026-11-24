{ config, ... }:
let
  inherit (config.flake.lib) sshHosts sshTailnetMatch;
in
{
  flake.modules.homeManager.ssh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      knownHosts = pkgs.writeText "homelab-known-hosts" (
        lib.concatLines (lib.mapAttrsToList (name: h: "${name} ${h.hostKey}") sshHosts)
      );

      base = {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          includes = [
            "~/.orbstack/ssh/config"
            "conf.d/*"
          ];
        };
      };
      impermanence = lib.mkIf (config.znix.impermanence.enable or false) {
        programs.ssh.extraConfig = ''
          UserKnownHostsFile /persist${config.home.homeDirectory}/.ssh/known_hosts
        '';
      };
      # `ssh <host>` goes over the tailnet while the host answers there and
      # over the LAN otherwise, so it works away from home and at home while
      # Tailscale is down. Tailnet IPs rather than names: the ts.zebradil.dev
      # wildcard resolves an unpublished host to junior.
      homelab = lib.mkIf config.znix.ssh.homelab.enable {
        programs.ssh.settings = lib.concatMapAttrs (name: h: {
          "${name}-tailnet" = lib.hm.dag.entryBefore [ name ] {
            header = sshTailnetMatch pkgs name h;
            HostName = h.tailnet;
          };
          ${name} = {
            HostName = h.lan;
            User = "suok";
            # One pinned key for both paths, kept out of the writable
            # known_hosts so a changed key fails instead of prompting.
            HostKeyAlias = name;
            GlobalKnownHostsFile = "${knownHosts}";
          };
        }) sshHosts;
      };
    in
    {
      options.znix.ssh.homelab.enable = lib.mkEnableOption "ssh aliases for the homelab hosts, reached over the tailnet or the LAN";

      config = lib.mkMerge [
        base
        impermanence
        homelab
      ];
    };
}
