_: {
  plugins = {

    # ─ Context ────────────────────────────────────────────────────
    # Sticky header showing current scope at top of buffer
    treesitter-context = {
      enable = true;
      settings = {
        max_lines = 5;
        min_window_height = 20;
      };
    };

    # ─ Lualine ────────────────────────────────────────────────────
    # Statusline + winbar breadcrumbs via aerial component
    lualine = {
      enable = true;
      settings = {
        options.globalstatus = true;
        winbar = {
          lualine_c = [
            {
              __unkeyed-1 = "aerial";
              colored = true;
              dense = false;
              dense_sep = ".";
              sep = " > ";
            }
          ];
        };
      };
    };

    # ─ Flash ──────────────────────────────────────────────────────
    # Label-based jump motions (enhances f/t/s and treesitter selection)
    flash.enable = true;

    # ─ Aerial ─────────────────────────────────────────────────────
    # Code outline and symbol navigation
    aerial = {
      enable = true;
      settings = {
        backends = [
          "treesitter"
          "lsp"
        ];
        layout = {
          min_width = 28;
          default_direction = "prefer_right";
        };
        show_guides = true;
        filter_kind = false;
      };
    };
  };
}
