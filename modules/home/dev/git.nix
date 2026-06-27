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
              useConfigOnly = true;
            };
            color.ui = true;
            core.autocrlf = "input";
            diff.colorMoved = "default";
            pull.ff = "only";
            push = {
              default = "simple";
              followTags = true;
            };
            merge = {
              tool = "vimdiff";
              conflictstyle = "diff3";
            };
            mergetool.prompt = false;
            init.defaultBranch = "main";
            tag.gpgSign = true;
            difftool = {
              trustExitCode = true;
              difftastic.cmd = ''difft "$LOCAL" "$REMOTE"'';
              nvim.cmd = ''nvim -d "$LOCAL" "$REMOTE"'';
            };
            alias = {
              dift = "difftool --tool=difftastic --no-prompt";
              dlog = "-c diff.external=difft log --ext-diff";
              dshow = "-c diff.external=difft show --ext-diff";
              ddiff = "-c diff.external=difft diff";
              lg = "!git lg1";
              lg1 = "!git lg1-specific --all";
              lg2 = "!git lg2-specific --all";
              lg3 = "!git lg3-specific --all";
              lg1-specific = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)'";
              lg2-specific = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'";
              lg3-specific = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset) %C(bold cyan)(committed: %cD)%C(reset) %C(auto)%d%C(reset)%n''          %C(white)%s%C(reset)%n''          %C(dim white)- %an <%ae> %C(reset) %C(dim white)(committer: %cn <%ce>)%C(reset)'";
            };
            url."ssh://git@github.com/".insteadOf = "https://github.com/";
          };
          ignores = [
            ".claude/settings.local.json"
            ".claude/worktrees"
            ".dir-locals.el"
            ".direnv"
            ".envrc"
            ".serena/*"
            ".vscode"
            "__pycache__"
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
