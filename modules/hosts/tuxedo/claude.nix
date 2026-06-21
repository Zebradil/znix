{ inputs, ... }:
{
  flake.modules.nixos.tuxedo-claude =
    { ... }:
    {
      imports = [
        inputs.self.modules.nixos.claude
        inputs.self.modules.nixos.claude-caveman
      ];

      znix.claude = {
        caveman.enable = true;

        profiles.personal = {
          enable = true;
          caveman = true;
          configDir = ".config/personal-claude";
          command = "claude";
          settings = {
            model = "opus[1m]";
            editorMode = "vim";
            effortLevel = "medium";
            verbose = true;
            # renovate-sweep: read + red-agent comment/push, merge stays gated
            permissions.allow = [
              "Bash(gh pr list:*)"
              "Bash(gh pr checks:*)"
              "Bash(gh pr view:*)"
              "Bash(gh run view:*)"
              "Bash(gh pr comment:*)"
              "Bash(git fetch:*)"
              "Bash(git worktree:*)"
              "Bash(git add:*)"
              "Bash(git commit:*)"
              "Bash(git push:*)"
              "Bash(nix flake check)"
              "Bash(nixos-rebuild build:*)"
              "Bash(darwin-rebuild build:*)"
            ];
          };
        };
      };
    };
}
