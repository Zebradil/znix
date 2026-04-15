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
          mappings = {
            # AstroNvim-style: l expands a dir, enters its first child when already
            # expanded, or opens a file. h collapses an expanded dir, or focuses
            # the parent node when on a leaf. Overrides the upstream default
            # l = focus_preview (focus_preview is intentionally left unbound).
            l.__raw = ''
              function(state)
                local node = state.tree:get_node()
                if node.type == "directory" then
                  if not node:is_expanded() then
                    require("neo-tree.sources.filesystem").toggle_directory(state, node)
                  elseif node:has_children() then
                    require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
                  end
                else
                  state.commands.open(state)
                end
              end
            '';
            h.__raw = ''
              function(state)
                local node = state.tree:get_node()
                if node.type == "directory" and node:is_expanded() then
                  require("neo-tree.sources.filesystem").toggle_directory(state, node)
                else
                  require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
                end
              end
            '';
          };
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
