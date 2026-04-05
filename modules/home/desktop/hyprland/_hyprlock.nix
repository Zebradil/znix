_: {
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 5;
      };
      background = [
        {
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
          brightness = 0.5;
        }
      ];
      input-field = [
        {
          monitor = "";
          size = "300, 50";
          position = "0, -200";
          halign = "center";
          valign = "center";
          dots_center = true;
          fade_on_empty = false;
          placeholder_text = "<i>Password</i>";
          outline_thickness = 2;
          outer_color = "rgb(fab387)"; # peach
          inner_color = "rgb(1e1e2e)"; # base
          font_color = "rgb(cdd6f4)"; # text
          check_color = "rgb(a6e3a1)"; # green
          fail_color = "rgb(f38ba8)"; # red
          capslock_color = "rgb(f9e2af)"; # yellow
        }
      ];
      label = [
        {
          monitor = "";
          text = "$USER";
          color = "rgb(cdd6f4)";
          font_size = 48;
          font_family = "IosevkaTerm NFM";
          position = "0, 80";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "$LAYOUT";
          color = "rgb(a6adc8)";
          font_size = 16;
          font_family = "IosevkaTerm NFM";
          position = "0, -280";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
