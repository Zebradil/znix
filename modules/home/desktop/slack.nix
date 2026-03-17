{ ... }:
{
  flake.modules.homeManager.slack =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        slack
      ];

      # home.persistence."/persist" = lib.mkIf osConfig.znix.impermanence.enable {
      #   directories = [ ".config/Slack" ];
      # };
    };
}
