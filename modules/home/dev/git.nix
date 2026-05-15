_: {
  flake.modules.homeManager.git =
    { config, ... }:
    {
      programs = {
        git = {
          enable = true;
          lfs.enable = true;
          settings = {
            user = {
              inherit (config.znix.user) name;
              inherit (config.znix.user) email;
            };
            pull.ff = "only";
            difftool = {
              trustExitCode = true;
              difftastic.cmd = ''difft "$LOCAL" "$REMOTE"'';
            };
            alias.dift = "difftool --tool=difftastic --no-prompt";
            url."ssh://git@github.com/".insteadOf = "https://github.com/";
          };
          ignores = [
            ".claude/settings.local.json"
            ".claude/worktrees"
            ".dir-locals.el"
            ".direnv"
            ".envrc"
            ".vscode"
          ];
        };

        difftastic.enable = true;

        delta = {
          enable = true;
          enableGitIntegration = true;
        };
      };
    };
}
