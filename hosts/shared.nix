{
  pkgs,
  user,
  ...
}:
{
  nix.settings.experimental-features = "nix-command flakes";

  # Allow the user to use substitutes
  nix.settings.trusted-users = [ user ];

  fonts.packages = with pkgs; [
    iosevka-bin
    nerd-fonts.iosevka-term
  ];

  services.nix-daemon.enable = true;

  # TODO: configure gpg integrations
  # programs.gnupg.agent.enable = true;
}
