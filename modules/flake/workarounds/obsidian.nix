{ ... }:
{
  znix.workarounds.obsidian = {
    systems = [ "aarch64-darwin" ];
    reason = "The .dmg wraps the app in a versioned folder, but nixpkgs still points sourceRoot at a bare Obsidian.app, so unpacking leaves nothing to chmod.";
    override = _pkgs: old: {
      sourceRoot = "Obsidian ${old.version}-universal/Obsidian.app";
    };
  };
}
