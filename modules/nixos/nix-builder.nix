{ config, lib, ... }:
let
  inherit (config.flake.lib) sshHosts sshTailnetMatch;
  inherit (sshHosts) daddy;

  # Clients authenticate with their own SSH host key, so no extra secret has
  # to be distributed: the nix daemon runs as root and can read it.
  clientHostKeys = {
    tuxedo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPuIvTIOpTTmf/v7zyZXQrDQwcce3VKR86IEn2IjsVS8";
  }
  // lib.genAttrs [ "junior" "d1" "d2" "d3" ] (host: sshHosts.${host}.hostKey);

  # CI runners build here without being able to inject unsigned paths.
  ciKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB0iD34JlFWilQpD1kreFa1K3O22ZFKTERsKA2CJqp74 nixci-spike"
  ];

  # The forced command limits a leaked key to talking to the store.
  storeOnly = nix: k: ''restrict,command="${nix}/bin/nix-daemon --stdio" ${k}'';
in
{
  flake.modules.nixos.nix-builder-server =
    { config, lib, ... }:
    {
      users.groups.nixremote = { };
      users.users.nixremote = {
        isSystemUser = true;
        group = "nixremote";
        useDefaultShell = true;
        openssh.authorizedKeys.keys = map (storeOnly config.nix.package) (lib.attrValues clientHostKeys);
      };

      users.groups.nixci = { };
      users.users.nixci = {
        isSystemUser = true;
        group = "nixci";
        useDefaultShell = true;
        openssh.authorizedKeys.keys = map (storeOnly config.nix.package) ciKeys;
      };

      # Trusted so clients can upload their unsigned build inputs. nixci stays
      # untrusted: a CI job must not poison the store other clients use.
      nix.settings.trusted-users = [ "nixremote" ];

      # Lets clients offload builds for the aarch64 RPi (toddler); emulated, slow.
      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
    };

  flake.modules.nixos.nix-builder-client =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.znix.nixBuilder;
      sshKey = (lib.head (lib.filter (k: k.type == "ed25519") config.services.openssh.hostKeys)).path;
    in
    {
      options.znix.nixBuilder.roaming = lib.mkEnableOption ''
        reaching the builder over the tailnet while it answers there, and over
        the LAN otherwise, for a client that leaves the LAN
      '';

      config = {
        nix.distributedBuilds = true;
        nix.buildMachines = [
          {
            hostName = if cfg.roaming then "daddy" else daddy.lan;
            protocol = "ssh-ng";
            sshUser = "nixremote";
            inherit sshKey;
            systems = [
              "x86_64-linux"
              "aarch64-linux"
            ];
            maxJobs = 8;
            speedFactor = 2;
            supportedFeatures = [
              "big-parallel"
              "kvm"
              "nixos-test"
            ];
          }
        ];
        # Let the builder fetch dependencies from its own caches instead of
        # receiving them over the client's uplink.
        nix.settings.builders-use-substitutes = true;

        programs.ssh.knownHosts.daddy = {
          hostNames = [ daddy.lan ];
          publicKey = daddy.hostKey;
        };
        # The nix daemon runs as root and reads only the system ssh_config.
        # Root's writable known_hosts is ignored, so only the key above passes.
        programs.ssh.extraConfig =
          lib.optionalString cfg.roaming ''
            ${sshTailnetMatch pkgs "daddy" daddy}
              HostName ${daddy.tailnet}
          ''
          + ''
            Host daddy ${daddy.lan}
              HostName ${daddy.lan}
              HostKeyAlias ${daddy.lan}
              UserKnownHostsFile /dev/null
              StrictHostKeyChecking yes
          '';
      };
    };
}
