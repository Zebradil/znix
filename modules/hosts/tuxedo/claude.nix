{ inputs, ... }:
{
  flake.modules.nixos.tuxedo-claude =
    { ... }:
    {
      imports = [
        inputs.self.modules.nixos.claude
        inputs.self.modules.nixos.claude-caveman
        inputs.self.modules.nixos.claude-ponytail
      ];

      znix.claude = {
        caveman.enable = true;
        ponytail.enable = true;
        profiles.personal = inputs.self.lib.claude.mkPersonalProfile { };
      };
    };
}
