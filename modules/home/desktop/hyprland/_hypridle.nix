let
  # A non-table argument to hl.dsp.dpms silently means "toggle".
  dpms = action: "hyprctl dispatch 'hl.dsp.dpms({ action = \"${action}\" })'";
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = dpms "on";
      };
      listener = [
        {
          timeout = 300; # 5 min: dim screen
          on-timeout = "brightnessctl -s set 10";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 330; # 5.5 min: lock
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 600; # 10 min: display off
          on-timeout = dpms "off";
          on-resume = dpms "on";
        }
        {
          timeout = 3600; # 60 min: suspend
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
