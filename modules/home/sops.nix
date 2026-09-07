{ inputs, ... }:
{
  # Shared home-manager sops wiring. Any home module that renders a sops secret
  # or template (kube, docker registry auth, ...) relies on this being imported
  # once — sops.age.keyFile is single-valued, so it must not be set per-module.
  flake.modules.homeManager.sops =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

      # Upstream's darwin activation calls `launchctl bootstrap` right after
      # `bootout`; teardown is asynchronous, so bootstrap intermittently fails
      # with "Bootstrap failed: 5: Input/output error" and aborts the whole
      # activation. Retry until launchd has released the label.
      home.activation.sops-nix = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
        lib.mkForce ''
          domain="gui/$(id -u ${config.home.username})"
          plist="${config.home.homeDirectory}/Library/LaunchAgents/org.nix-community.home.sops-nix.plist"
          /bin/launchctl bootout "$domain/org.nix-community.home.sops-nix" || true
          for i in 1 2 3 4 5 6 7 8 9 10; do
            if /bin/launchctl bootstrap "$domain" "$plist"; then
              break
            fi
            if [ "$i" = 10 ]; then
              echo "sops-nix: launchctl bootstrap failed after 10 attempts" >&2
              exit 1
            fi
            sleep 0.5
          done
        ''
      );
    };
}
