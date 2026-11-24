{ config, lib, ... }:
let
  inherit (config.flake.lib) sshHosts;
  inherit (config.flake.modules.nixos) ssh-hosts;

  # Clients authenticate with their own SSH host key, so no extra secret has
  # to be distributed: the nix daemon runs as root and can read it.
  clientHostKeys = {
    tuxedo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPuIvTIOpTTmf/v7zyZXQrDQwcce3VKR86IEn2IjsVS8";
  }
  // lib.mapAttrs (_: h: h.hostKey) (removeAttrs sshHosts [ "daddy" ]);
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
        # The forced command limits a leaked client key to talking to the store.
        openssh.authorizedKeys.keys = map (
          k: ''restrict,command="${config.nix.package}/bin/nix-daemon --stdio" ${k}''
        ) (lib.attrValues clientHostKeys);
      };

      # Trusted so clients can upload their unsigned build inputs.
      nix.settings.trusted-users = [ "nixremote" ];

      # Lets clients offload builds for the aarch64 RPi (toddler); emulated, slow.
      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
    };

  flake.modules.nixos.nix-builder-client =
    { config, lib, ... }:
    let
      sshKey = (lib.head (lib.filter (k: k.type == "ed25519") config.services.openssh.hostKeys)).path;
    in
    {
      imports = [ ssh-hosts ];

      nix.distributedBuilds = true;
      nix.buildMachines = [
        {
          hostName = "daddy";
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
    };
}
