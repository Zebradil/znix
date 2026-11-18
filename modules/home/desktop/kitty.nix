_: {
  flake.modules.homeManager.kitty =
    {
      pkgs,
      lib,
      isDarwin,
      ...
    }:
    let
      fontFamily =
        if isDarwin then "family='IosevkaTerm Nerd Font Mono'" else "family='IosevkaTerm Nerd Font'";
      fontSize = if isDarwin then 18.0 else 12.0;
      tabMod = if isDarwin then "cmd" else "ctrl";
      themeDir = "${pkgs.kitty-themes}/share/kitty-themes/themes";
      themes = {
        dark = "ayu";
        light = "ayu_light";
        noPreference = "ayu";
      };
    in
    {
      # Checked in the generation builder, not with pathExists during evaluation:
      # that would build kitty-themes at eval time, which breaks read-only and
      # IFD-free evaluation (nix eval --read-only, CI cache probes).
      home.extraBuilderCommands = lib.concatMapStrings (name: ''
        test -f ${themeDir}/${name}.conf || { echo "kitty: theme '${name}' not found in kitty-themes" >&2; exit 1; }
      '') (lib.unique (lib.attrValues themes));

      programs.kitty = {
        enable = true;
        font = {
          name = "${fontFamily} style=Light";
          size = fontSize;
        };
        settings = {
          italic_font = "${fontFamily} style='Light Italic'";

          scrollback_lines = 10000;
          # enable_audio_bell = false;
          # confirm_os_window_close = 0;
          # copy_on_select = "clipboard";
          update_check_interval = 0;
          tab_title_template = "{index}: {title}{' [Z]' if layout_name == 'stack' else ''}";
          enabled_layouts = "splits,horizontal,vertical,tall,fat,stack";
          allow_remote_control = true;

          macos_option_as_alt = true;
        };
        autoThemeFiles = themes;
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
          "ctrl+a>space" = "next_layout";
          "ctrl+a>s" = "launch --allow-remote-control kitty +kitten broadcast";
          "ctrl+Tab" = "focus_to_last_used_tab";
        }
        # kitty's macOS default maps cmd+enter to new_window; no_op hands it to the app (Claude/opencode submit).
        // lib.optionalAttrs isDarwin { "cmd+enter" = "no_op"; }
        // (builtins.listToAttrs (
          builtins.genList (i: {
            name = "ctrl+a>${toString i}";
            value = "goto_tab ${toString i}";
          }) 9
        ))
        // (builtins.listToAttrs (
          builtins.genList (i: {
            name = "${tabMod}+${toString (i + 1)}";
            value = "goto_tab ${toString (i + 1)}";
          }) 9
        ));
      };
    };
}
