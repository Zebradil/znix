_: {
  flake.modules.homeManager.manual = _: {
    # Disable home-manager manpages to avoid a spurious Nix warning during
    # evaluation: "Using 'builtins.derivation' to create a derivation named
    # 'options.json' that references the store path '...-source' without a
    # proper context."
    #
    # Root cause: building manpages forces nixosOptionsDoc, which references
    # nixpkgs source paths without proper string context — an upstream
    # home-manager issue. The manpages (man home-configuration.nix) are
    # available online and rarely needed locally.
    manual.manpages.enable = false;
  };
}
