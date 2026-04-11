_: {
  flake.modules.homeManager.kitty =
    { pkgs, lib, ... }:
    let
      fontFamily = "family='IosevkaTerm Nerd Font'";
      themeDir = "${pkgs.kitty-themes}/share/kitty-themes/themes";
      assertTheme =
        name:
        assert lib.assertMsg (builtins.pathExists "${themeDir}/${name}.conf")
          "kitty: theme '${name}' not found in kitty-themes";
        name;
    in
    {
      programs.kitty = {
        enable = true;
        font = {
          name = "${fontFamily} style=Light";
          size = 12.0;
        };
        settings = {
          italic_font = "${fontFamily} style='Light Italic'";

          scrollback_lines = 10000;
          # enable_audio_bell = false;
          # confirm_os_window_close = 0;
          # copy_on_select = "clipboard";
          update_check_interval = 0;
          enabled_layouts = "splits,stack";
          allow_remote_control = true;
        };
        autoThemeFiles = {
          dark = assertTheme "ayu";
          light = assertTheme "ayu_light";
          noPreference = assertTheme "ayu";
        };
        keybindings = {
          "ctrl+a>c" = "new_tab_with_cwd";
          "ctrl+a>x" = "close_window";
          "ctrl+a>n" = "next_tab";
          "ctrl+a>p" = "previous_tab";
          "ctrl+a>shift+\\" = "launch --cwd=current --location=vsplit";
          "ctrl+a>-" = "launch --cwd=current --location=hsplit";
          "ctrl+a>h" = "neighboring_window left";
          "ctrl+a>j" = "neighboring_window down";
          "ctrl+a>k" = "neighboring_window up";
          "ctrl+a>l" = "neighboring_window right";
          "ctrl+a>z" = "toggle_layout stack";
          "ctrl+a>s" = "launch --allow-remote-control kitty +kitten broadcast";
        };
      };
    };
}
