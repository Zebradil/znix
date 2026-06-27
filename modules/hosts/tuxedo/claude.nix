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
        profiles.personal = inputs.self.lib.claude.mkPersonalProfile { };
      };
    };
}
