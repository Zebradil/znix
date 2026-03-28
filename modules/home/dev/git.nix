_: {
  flake.modules.homeManager.git =
    { config, ... }:
    {
      programs = {
        git = {
          enable = true;
          settings = {
            user = {
              inherit (config.znix.user) name;
              inherit (config.znix.user) email;
            };
            pull.ff = "only";
            difftool.trustExitCode = true;
            url."ssh://git@github.com/".insteadOf = "https://github.com/";
          };
          ignores = [
            ".dir-locals.el"
            ".direnv"
            ".envrc"
            ".vscode"
          ];
        };

        difftastic = {
          enable = true;
          git.enable = true;
        };

        delta = {
          enable = true;
          # Conflicts with difftastic.git.enable
          # enableGitIntegration = true;
        };
      };
    };
}
