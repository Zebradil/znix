{ pkgs, ... }:
let
  monitor-switch = pkgs.writeShellApplication {
    name = "monitor-switch";
    runtimeInputs = with pkgs; [
      anyrun
      hyprland
      jq
      libnotify
    ];
    text = builtins.readFile ./monitor-switch.sh;
  };

  monitor-switch-daemon = pkgs.writeShellApplication {
    name = "monitor-switch-daemon";
    runtimeInputs = [
      monitor-switch
      pkgs.socat
      pkgs.hyprland
      pkgs.jq
      pkgs.libnotify
    ];
    excludeShellChecks = [ "SC2312" ];
    text = builtins.readFile ./monitor-switch-daemon.sh;
  };
in
{
  home.packages = [
    monitor-switch
  ];

  wayland.windowManager.hyprland.settings.bind = [
    "$mod, P, exec, hypr-exec monitor-switch --pick"
  ];

  systemd.user.services.monitor-switch-daemon = {
    Unit = {
      Description = "Auto-switch display preset on monitor plug/unplug";
      After = [ "hyprland-session.target" ];
    };
    Service = {
      ExecStart = "${monitor-switch-daemon}/bin/monitor-switch-daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };
}
