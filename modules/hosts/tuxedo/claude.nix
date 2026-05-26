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
          };
        };
      };
    };
}
