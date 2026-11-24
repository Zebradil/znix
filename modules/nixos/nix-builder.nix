_:
let
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
    { config, lib, ... }:
    let
      cfg = config.znix.nixBuilder;
      sshKey = (lib.head (lib.filter (k: k.type == "ed25519") config.services.openssh.hostKeys)).path;
    in
    {
      # The LAN name resolves to daddy's LAN address everywhere, but no client
      # accepts the tailnet's subnet routes, so a roaming client must use the
      # tailnet name instead.
      options.znix.nixBuilder.host = lib.mkOption {
        type = lib.types.str;
        default = "daddy.lan.zebradil.dev";
        example = "daddy.ts.zebradil.dev";
        description = "Address clients reach the remote builder (daddy) at.";
      };

      config = {
        nix.distributedBuilds = true;
        nix.buildMachines = [
          {
            hostName = cfg.host;
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
        programs.ssh.knownHosts.${cfg.host}.publicKey = builderHostKey;
      };
    };
}
