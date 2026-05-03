_: {
  flake.modules.nixos.docker =
    {
      config,
      lib,
      ...
    }:
    {
      options.znix.docker = {
        enable = lib.mkEnableOption "Docker";
        binfmt.enable = lib.mkEnableOption "binfmt/QEMU emulation for multi-arch Docker builds (aarch64-linux)";
      };

      config = lib.mkIf config.znix.docker.enable (
        lib.mkMerge [
          { virtualisation.docker.enable = true; }
          (lib.mkIf config.znix.docker.binfmt.enable {
            boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
            boot.binfmt.registrations."aarch64-linux".fixBinary = true;
          })
        ]
      );
    };

  flake.modules.homeManager.docker =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      instanceConfig = builtins.toJSON {
        Name = "multiarch";
        Driver = "docker-container";
        Nodes = [
          {
            Name = "multiarch0";
            Endpoint = "unix:///var/run/docker.sock";
            Platforms = null;
            DriverOpts = null;
            Flags = [ "--allow-insecure-entitlement=network.host" ];
            Files = null;
          }
        ];
        Dynamic = false;
      };

      currentConfig = builtins.toJSON {
        Key = "unix:///var/run/docker.sock";
        Name = "multiarch";
        Global = false;
      };
    in
    {
      options.znix.docker.multiarchBuilder.enable =
        lib.mkEnableOption "docker-container buildx builder for multi-arch builds";

      config = lib.mkIf config.znix.docker.multiarchBuilder.enable {
        home.activation.dockerMultiarchBuilder = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p "$HOME/.docker/buildx/instances"

          # Always sync the instance config so it stays up to date with the Nix config
          cp ${pkgs.writeText "buildx-multiarch-instance" instanceConfig} \
             "$HOME/.docker/buildx/instances/multiarch"
          chmod 644 "$HOME/.docker/buildx/instances/multiarch"

          # Only set the default builder if the user hasn't chosen one yet
          if [ ! -f "$HOME/.docker/buildx/current" ]; then
            cp ${pkgs.writeText "buildx-current" currentConfig} \
               "$HOME/.docker/buildx/current"
            chmod 644 "$HOME/.docker/buildx/current"
          fi
        '';
      };
    };
}
