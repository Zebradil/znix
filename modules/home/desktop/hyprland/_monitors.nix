{ lib, pkgs, ... }:
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

  monitor-switch-default = pkgs.writeShellApplication {
    name = "monitor-switch-default";
    runtimeInputs = [
      monitor-switch
      pkgs.coreutils
    ];
    text = ''
      runtime_dir="$XDG_RUNTIME_DIR"
      if [ -z "$runtime_dir" ]; then
        runtime_dir="/run/user/$(id -u)"
      fi
      hypr_dir="$runtime_dir/hypr"

      # Systemd user activation does not reliably inherit Hyprland session env,
      # so discover live instances directly from the runtime dir.
      [ -d "$hypr_dir" ] || exit 0

      for instance_dir in "$hypr_dir"/*; do
        [ -S "$instance_dir/.socket.sock" ] || continue
        HYPRLAND_INSTANCE_SIGNATURE="$(basename "$instance_dir")" \
          XDG_RUNTIME_DIR="$runtime_dir" \
          monitor-switch --default >/dev/null 2>&1 || true
      done
    '';
  };
in
{
  home.packages = [
    monitor-switch
  ];

  xdg.configFile."systemd/user/nixos-activation.service.d/monitor-switch-default.conf".text = ''
    [Service]
    ExecStartPost=${monitor-switch-default}/bin/monitor-switch-default
  '';

  wayland.windowManager.hyprland.settings.bind = [
    "$mod, P, exec, hypr-exec monitor-switch --pick"
  ];
  wayland.windowManager.hyprland.settings.exec-once = [
    "hypr-exec monitor-switch --default"
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
