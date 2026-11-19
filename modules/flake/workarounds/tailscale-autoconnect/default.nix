_: {
  workarounds.tailscale-autoconnect = {
    file = "modules/flake/workarounds/tailscale-autoconnect";
    systems = [ "x86_64-linux" ];
    reason = "tailscaled-autoconnect leaks the auth key, cannot log in again past prefs from extraSetFlags, and exits on a cached netmap before control accepts the node (NixOS/nixpkgs#589793, #589794, #589795).";
    # _module.nix is nixpkgs' tailscale.nix at 2074cc6 with the three PRs
    # applied, kept unformatted so it diffs cleanly against upstream.
    module.nixos = {
      disabledModules = [ "services/networking/tailscale.nix" ];
      imports = [ ./_module.nix ];
    };
    # One marker per PR. A PR merged with other wording keeps this failing, so
    # recheck the markers when the PRs merge.
    fixed =
      pkgs:
      pkgs.runCommand "tailscale-autoconnect-fixed" { } ''
        module=${pkgs.path}/nixos/modules/services/networking/tailscale.nix
        for marker in 'auth-key "file:' '"--reset"' 'Self.Online'; do
          if ! grep -qF -- "$marker" "$module"; then
            echo "$module lacks $marker" >&2
            exit 1
          fi
        done
        touch $out
      '';
  };
}
