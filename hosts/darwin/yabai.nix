{...}: {
  services.yabai = {
    enable = true;
    config = {
      debug_output = "on";
      external_bar = "off:40:0";
      menubar_opacity = 1.0;
      mouse_follows_focus = "on";
      focus_follows_mouse = "autofocus";
      display_arrangement_order = "default";
      window_origin_display = "focused";
      window_placement = "second_child";
      window_zoom_persist = "on";
      insert_feedback_color = "0xffd75f5f";
      split_ratio = 0.50;
      split_type = "auto";
      auto_balance = "off";
      top_padding = 0;
      bottom_padding = 0;
      left_padding = 0;
      right_padding = 0;
      window_gap = 0;
      layout = "bsp";
      mouse_modifier = "ctrl";
      mouse_action1 = "move";
      mouse_action2 = "resize";
      mouse_drop_action = "swap";
    };
    extraConfig = ''
      # bar configuration
      #yabai -m signal --add event=window_focused   action="sketchybar --trigger window_focus"
      #yabai -m signal --add event=window_created   action="sketchybar --trigger windows_on_spaces"
      #yabai -m signal --add event=window_destroyed action="sketchybar --trigger windows_on_spaces"

      # rules
      yabai -m rule --add app="^System Settings$"    manage=off
      yabai -m rule --add app="^System Information$" manage=off
      yabai -m rule --add app="^System Preferences$" manage=off
      yabai -m rule --add title="Preferences$"       manage=off
      yabai -m rule --add title="Settings$"          manage=off

      # workspace management
      yabai -m space 1  --label www
      yabai -m space 2  --label code
      yabai -m space 3  --label chat
      yabai -m space 4  --label media
      yabai -m space 5  --label personal
      yabai -m space 6  --label misc

      # assign apps to spaces
      yabai -m rule --add app="Firefox" space=www

      yabai -m rule --add app="iTerm2" space=code

      yabai -m rule --add app="Slack" space=chat

      yabai -m rule --add app="YouTube Music" space=media

      yabai -m rule --add app="Personal Firefox" space=personal
    '';
  };
}
