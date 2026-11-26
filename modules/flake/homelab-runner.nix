{ lib, ... }:
{
  # Image for the ephemeral ARC runner pods of the homelab k3s cluster. Jobs
  # evaluate here and send builds to daddy's store as the untrusted `nixci` user,
  # so the image carries the same Nix as daddy's daemon (both from this flake's
  # nixpkgs) and no build toolchains. No sudo: the runner user cannot escalate.
  perSystem =
    { pkgs, ... }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        homelab-runner-image =
          let
            uid = "1001";
            home = "/home/runner";

            tools = pkgs.buildEnv {
              name = "homelab-runner-tools";
              paths = with pkgs; [
                bashInteractive
                coreutils
                diffutils
                findutils
                gawk
                gnugrep
                gnused
                gnutar
                gzip
                xz
                zstd
                procps
                which
                git
                openssh
                curl
                jq
                nix
                nix-fast-build
                # Image builds go to a remote BuildKit (buildx `remote` driver); there is no daemon here.
                docker-client
                github-runner
              ];
              pathsToLink = [
                "/bin"
                "/share"
              ];
            };

            nixConf = pkgs.writeTextDir "etc/nix/nix.conf" ''
              experimental-features = nix-command flakes
              # Single-user store owned by the runner user.
              build-users-group =
              # daddy's daemon takes cores from the client, even an untrusted one,
              # so this caps each build there. The default 0 lets every build use
              # all 16 threads, and 11 concurrent jobs then reach a load of 185.
              cores = 4
            '';

            nss = pkgs.dockerTools.fakeNss.override {
              extraPasswdLines = [ "runner:x:${uid}:${uid}:runner:${home}:/bin/bash" ];
              extraGroupLines = [ "runner:x:${uid}:" ];
            };
          in
          pkgs.dockerTools.buildLayeredImageWithNixDb {
            name = "homelab-runner";
            contents = [
              tools
              nixConf
              nss
              pkgs.dockerTools.binSh
              pkgs.dockerTools.usrBinEnv
              pkgs.dockerTools.caCertificates
            ];
            fakeRootCommands = ''
              mkdir -p .${home} tmp nix/store
              chmod 1777 tmp
              chown -R ${uid}:${uid} .${home} nix/var
              # Only the directory: store paths stay read-only, but the runner can add new ones.
              chown ${uid}:${uid} nix nix/store
            '';
            config = {
              User = "${uid}:${uid}";
              WorkingDir = home;
              Cmd = [ "/bin/run.sh" ];
              Env = [
                "HOME=${home}"
                "USER=runner"
                "PATH=/bin"
                "LANG=C.UTF-8"
                "RUNNER_ROOT=${home}"
                "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
                "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
              ];
              Labels."org.opencontainers.image.source" = "https://github.com/Zebradil/znix";
            };
          };
      };
    };
}
