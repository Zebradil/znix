_: {
  wayland.windowManager.hyprland.settings = {
    input = {
      repeat_delay = 200;
      repeat_rate = 50;
      kb_layout = "us,us,ru";
      kb_variant = ",dvorak,phonetic_dvorak";
      kb_options = "grp:caps_toggle,ctrl:swap_lalt_lctl";
      resolve_binds_by_sym = true;
      touchpad = {
        natural_scroll = true;
        tap-to-click = true;
        clickfinger_behavior = true;
        drag_lock = true;
      };
    };
    device = {
      name = "splitkb.com-aurora-sofle-v2-rev1";
      kb_layout = "us,ru";
      kb_variant = ",phonetic";
      kb_options = "grp:caps_toggle";
    };
    gesture = "3, horizontal, workspace";
    gestures = {
      workspace_swipe_distance = 300;
      workspace_swipe_cancel_ratio = 0.5;
      workspace_swipe_create_new = true;
    };
  };
}
