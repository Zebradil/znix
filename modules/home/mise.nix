_: {
  flake.modules.homeManager.mise =
    { pkgs, ... }:
    {
      programs.mise = {
        enable = true;
        globalConfig = {
          settings = {
            github.credential_command = "${pkgs.gh}/bin/gh auth token";
          };
        };
      };
    };
}
