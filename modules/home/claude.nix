{ ... }:
{
  flake.modules.homeManager.claude =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        claude-code
        claude-monitor
      ];

      # home.persistence."/persist" = lib.mkIf (osConfig.znix.impermanence.enable or false) {
      #   directories = [ ".config/claude" ];
      # };
    };
}
