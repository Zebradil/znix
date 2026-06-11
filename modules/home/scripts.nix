{ self, ... }:
{
  flake.modules.homeManager.scripts =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.znixctl ];

      home.file.".local/bin" = {
        source = "${self}/assets/bin";
        recursive = true;
      };

      # Compat symlink so existing callers (e.g. gke.zsh) and muscle memory keep working.
      # Uses basename dispatch in znixctl/main.go to route to the right subcommand.
      home.file.".local/bin/drain-nodes".source = pkgs.writeShellScript "drain-nodes" ''
        exec ${pkgs.znixctl}/bin/znixctl drain-nodes "$@"
      '';
    };
}
