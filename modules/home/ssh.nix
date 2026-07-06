_: {
  flake.modules.homeManager.ssh =
    {
      config,
      lib,
      ...
    }:
    let
      base = {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          includes = [
            "~/.orbstack/ssh/config"
            "conf.d/*"
          ];
        };
      };
      impermanence = lib.mkIf (config.znix.impermanence.enable or false) {
        programs.ssh.extraConfig = ''
          UserKnownHostsFile /persist${config.home.homeDirectory}/.ssh/known_hosts
        '';
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
