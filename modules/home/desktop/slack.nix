_: {
  flake.modules.homeManager.slack =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        slack
      ];

      # home.persistence."/persist" = lib.mkIf config.znix.impermanence.enable {
      #   directories = [ ".config/Slack" ];
      # };
    };
}
