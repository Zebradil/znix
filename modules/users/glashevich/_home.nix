{ pkgs, ... }:
{
  znix.user = {
    name = "German Lashevich";
    email = "german.lashevich@gmail.com";
  };
  sshPublicKey = builtins.readFile ./ssh.pub;
  # Darwin-specific extra packages
  home.packages = with pkgs; [
    iterm2
    monitorcontrol
    skhd
    terminal-notifier
  ];
}
