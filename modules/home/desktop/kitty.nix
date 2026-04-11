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
        };
        autoThemeFiles = {
          dark = assertTheme "ayu";
          light = assertTheme "ayu_light";
          noPreference = assertTheme "ayu";
        };
        keybindings = {
          "ctrl+shift+enter" = "new_window_with_cwd";
          "ctrl+shift+]" = "next_window";
          "ctrl+shift+[" = "previous_window";
          "ctrl+shift+w" = "close_window";
          "ctrl+shift+l" = "next_layout";
        };
      };
    };
}
