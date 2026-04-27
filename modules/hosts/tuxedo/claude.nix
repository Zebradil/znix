{ inputs, ... }:
{
  flake.modules.nixos.tuxedo-claude =
    { ... }:
    {
      imports = [ inputs.self.modules.nixos.claude ];

      znix.claude.profiles.personal = {
        enable = true;
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
}
