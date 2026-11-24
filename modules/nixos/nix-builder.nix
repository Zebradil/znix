_:
let
  builderAlias = "daddy-builder";
  builderTailnet = "daddy.ts.zebradil.dev";
  builderLan = "daddy.lan.zebradil.dev";
  builderHostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIunTmGGD83WKotySV3vBD5aD/luU8p1sYCu8UxlyvwK";

  # Clients authenticate with their own SSH host key, so no extra secret has
  # to be distributed: the nix daemon runs as root and can read it.
  clientHostKeys = {
    tuxedo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPuIvTIOpTTmf/v7zyZXQrDQwcce3VKR86IEn2IjsVS8";
    junior = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMaqOxLFO1pP1TGiMKVGs5PFPgGZcnhExjtMVmVTOhYc";
    d1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATZnTfglZ7nTAGZdcmtjTUhfjfgOOgciC+A4SFHTWk0";
    d2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK626ImCb3DXC5alsmgK1yt8GXJ2gyQ1gxrR7lyweGBi";
    d3 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMx91ZNA3xd2XbT4ryR/I05saxJK8cymMvFz0YdRLWim";
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
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      sshKey = (lib.head (lib.filter (k: k.type == "ed25519") config.services.openssh.hostKeys)).path;
    in
    {
      nix.distributedBuilds = true;
      nix.buildMachines = [
        {
          hostName = builderAlias;
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

      # The address is picked per connection. The tailnet is preferred because
      # it also works away from home; the LAN fallback keeps builds working at
      # home while Tailscale is down. Probing the LAN address first would, on
      # a foreign LAN in the same range, reach a stranger's host. No client
      # accepts the tailnet's subnet routes, so the LAN address is reachable
      # only from the LAN itself.
      programs.ssh.extraConfig = ''
        Match originalhost ${builderAlias} exec "${pkgs.netcat}/bin/nc -z -w1 ${builderTailnet} 22"
          HostName ${builderTailnet}
        Host ${builderAlias}
          HostName ${builderLan}
          HostKeyAlias ${builderAlias}
      '';
      programs.ssh.knownHosts.${builderAlias}.publicKey = builderHostKey;
    };
}
