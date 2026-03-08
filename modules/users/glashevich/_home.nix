{ pkgs, ... }:
{
  # Darwin-specific extra packages
  home.packages = with pkgs; [
    iterm2
    monitorcontrol
    skhd
    terminal-notifier
  ];
}
