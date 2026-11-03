_: {
  wayland.windowManager.hyprland.settings = {
    config = {
      input = {
        repeat_delay = 250;
        repeat_rate = 35;
        kb_layout = "us,us,ru";
        kb_variant = ",dvorak,phonetic_dvorak";
        kb_options = "grp:caps_toggle,ctrl:swap_lalt_lctl";
        resolve_binds_by_sym = true;
        touchpad = {
          natural_scroll = true;
          tap_to_click = true;
          clickfinger_behavior = true;
          drag_lock = true;
        };
      };
      gestures = {
        workspace_swipe_distance = 300;
        workspace_swipe_cancel_ratio = 0.5;
        workspace_swipe_create_new = true;
      };
    };
    device = [
      {
        name = "splitkb.com-aurora-sofle-v2-rev1";
        kb_layout = "us,ru";
        kb_variant = ",phonetic";
        kb_options = "grp:caps_toggle";
      }
      {
        name = "keychron--keychron-link-km";
        natural_scroll = true;
      }
    ];
    gesture = {
      fingers = 4;
      direction = "horizontal";
      action = "workspace";
    };
  };
}
