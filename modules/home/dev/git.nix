_: {
  flake.modules.homeManager.git =
    { config, ... }:
    {
      programs.git = {
        enable = true;
        settings.user = {
          inherit (config.znix.user) name;
          inherit (config.znix.user) email;
        };
        ignores = [
          ".dir-locals.el"
          ".direnv"
          ".envrc"
          ".vscode"
        ];
      };

      programs.difftastic = {
        enable = true;
        git.enable = true;
      };
    };
}
