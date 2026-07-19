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
            # Static emulator + fix-binary (F flag): the kernel preloads a
            # self-contained qemu, so emulation works where /nix/store isn't
            # mounted (docker containers) AND inside the nix build sandbox.
            # A bare fixBinary=true preloads only the dynamic binfmt-P wrapper,
            # which re-execs qemu from /nix/store — ENOENT in both cases.
            boot.binfmt.preferStaticEmulators = true;
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
      auth = config.znix.docker.registryAuth;

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
      options.znix.docker = {
        multiarchBuilder.enable = lib.mkEnableOption "docker-container buildx builder for multi-arch builds";

        # Renders a single ~/.docker/config.json from sops secrets. Every registry ×
        # endpoint becomes an `auths` entry; endpoints under one registry share its
        # credential. Parametrized per-user via sopsFile.
        registryAuth = {
          enable = lib.mkEnableOption "sops-rendered ~/.docker/config.json registry credentials";
          sopsFile = lib.mkOption {
            type = lib.types.path;
            description = "sops file holding every referenced credential key.";
          };
          registries = lib.mkOption {
            description = "Registries to authenticate to, keyed by an arbitrary label.";
            default = { };
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  endpoints = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    description = "Registry hosts sharing this credential; each becomes an `auths` key.";
                    example = [
                      "oci.zebradil.dev"
                      "oci.lan.zebradil.dev"
                    ];
                  };
                  # Two mutually exclusive credential forms (asserted below):
                  #   split : usernameSecret + passwordSecret -> plaintext username/password
                  #           fields. Docker keeps these verbatim when `auth` is absent, so
                  #           no base64 packing is needed.
                  #   blob  : authSecret -> the `auth` field, base64(`user:password`). Use for
                  #           registries where the split fields aren't honored.
                  usernameSecret = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "sops key holding the plaintext username.";
                  };
                  passwordSecret = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "sops key holding the plaintext password.";
                  };
                  authSecret = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "sops key holding base64(`user:password`) for the `auth` field.";
                  };
                };
              }
            );
          };
        };
      };

      config = lib.mkMerge [
        (lib.mkIf config.znix.docker.multiarchBuilder.enable {
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
        })

        (lib.mkIf auth.enable (
          let
            ph = config.sops.placeholder;

            isSplit = r: r.usernameSecret != null;

            # The credential attrs for one registry, keyed into every one of its
            # endpoint hosts. Split emits plaintext username/password (docker keeps
            # them when `auth` is absent); blob emits the `auth` field directly.
            credOf =
              r:
              if isSplit r then
                {
                  username = ph.${r.usernameSecret};
                  password = ph.${r.passwordSecret};
                }
              else
                { auth = ph.${r.authSecret}; };

            # Flatten registries × endpoints into a single host-keyed auths map.
            authsEntries = lib.concatMap (r: map (host: lib.nameValuePair host (credOf r)) r.endpoints) (
              lib.attrValues auth.registries
            );

            # Distinct sops keys across all registries; attrset merge dedupes shared keys.
            secretKeys = lib.concatMap (
              r:
              if isSplit r then
                [
                  r.usernameSecret
                  r.passwordSecret
                ]
              else
                [ r.authSecret ]
            ) (lib.attrValues auth.registries);
          in
          {
            assertions = lib.mapAttrsToList (name: r: {
              assertion =
                (r.usernameSecret != null && r.passwordSecret != null && r.authSecret == null)
                || (r.authSecret != null && r.usernameSecret == null && r.passwordSecret == null);
              message = "znix.docker.registryAuth.registries.${name}: set either usernameSecret + passwordSecret, or authSecret alone.";
            }) auth.registries;

            sops.secrets = lib.genAttrs secretKeys (_: {
              sopsFile = auth.sopsFile;
            });

            sops.templates."docker-config" = {
              path = "${config.home.homeDirectory}/.docker/config.json";
              mode = "0400";
              content = builtins.toJSON { auths = lib.listToAttrs authsEntries; };
            };
          }
        ))
      ];
    };
}
