_: {
  flake.modules.homeManager.mise =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      base = {
        programs.mise = {
          enable = true;
          globalConfig = {
            settings = {
              github.credential_command = "${pkgs.gh}/bin/gh auth token";
            };
          };
        };
      };
      impermanence = lib.mkIf config.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".local/share/mise" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
