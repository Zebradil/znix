_: {
  flake.modules.homeManager.zoxide =
    { lib, config, ... }:
    let
      base = {
        programs.zoxide.enable = true;
        programs.zsh.sessionVariables._ZO_FZF_OPTS = "+s --preview 'eza -l --no-permissions --no-user --no-filesize --group-directories-first --color=always {2..} | head -200'";
      };
      impermanence = lib.mkIf config.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".local/share/zoxide" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
