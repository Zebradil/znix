{ pkgs, ... }:
{
  plugins = {

    # ─ UI ─────────────────────────────────────────────────────────
    neo-tree = {
      enable = true;
      settings = {
        close_if_last_window = true;
        filesystem = {
          filtered_items = {
            hide_dotfiles = false;
            hide_gitignored = true;
          };
          follow_current_file.enabled = true;
        };
        window = {
          position = "left";
          width = 30;
        };
      };
    };

    which-key.enable = true;

    snacks = {
      enable = true;
      settings = {
        bigfile.enabled = true;
        dashboard = {
          enabled = true;
          sections = [
            { section = "header"; }
            {
              section = "keys";
              gap = 1;
              padding = 1;
            }
            { section = "recent_files"; }
          ];
        };
        indent.enabled = true;
        input.enabled = true;
        notifier = {
          enabled = true;
          timeout = 3000;
        };
        picker.enabled = true;
        quickfile.enabled = true;
        scratch.enabled = true;
        statuscolumn.enabled = true;
        words.enabled = true;
      };
    };

    todo-comments.enable = true;

    toggleterm = {
      enable = true;
      settings = {
        size = 20;
        open_mapping = "[[<C-\\>]]";
        direction = "horizontal";
      };
    };

    mini = {
      enable = true;
      modules.icons = { };
    };

    # ─ Editor ─────────────────────────────────────────────────────
    nvim-autopairs.enable = true;
    illuminate.enable = true;
  };

  # ── Extra plugins (no native nixvim module) ──────────────────────
  extraPlugins = with pkgs.vimPlugins; [
    CopilotChat-nvim
    tree-sitter-queries-nvim
    tree-sitter-test_highlights-nvim
    tree-sitter-ytt_annotation-nvim
    vim-abolish
  ];
}
