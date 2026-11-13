_:
let
  # The builder is reached over the tailnet name so roaming clients work too;
  # on the LAN Tailscale connects directly.
  builderHost = "daddy.ts.zebradil.dev";
  builderHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIunTmGGD83WKotySV3vBD5aD/luU8p1sYCu8UxlyvwK";

  # Clients authenticate with their own SSH host key, so no extra secret has
  # to be distributed: the nix daemon runs as root and can read it.
  clientHostKeys = {
    tuxedo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPuIvTIOpTTmf/v7zyZXQrDQwcce3VKR86IEn2IjsVS8";
  };
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
      nix.distributedBuilds = true;
      nix.buildMachines = [
        {
          hostName = builderHost;
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
      programs.ssh.knownHosts.${builderHost}.publicKey = builderHostKey;
    };
}
