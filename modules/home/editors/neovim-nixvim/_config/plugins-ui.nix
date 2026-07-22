{ pkgs, ... }:
{
  plugins = {

    # ─ UI ─────────────────────────────────────────────────────────
    which-key = {
      enable = true;
      settings = {
        spec = [
          {
            __unkeyed-1 = "<leader>64";
            group = "Base64";
            icon = "󰌶 ";
          }
          {
            __unkeyed-1 = "<leader>a";
            group = "AI / Aerial";
            icon = "󰚩 ";
          }
          {
            __unkeyed-1 = "<leader>b";
            group = "Buffer";
            icon = "󰈔 ";
          }
          {
            __unkeyed-1 = "<leader>c";
            group = "Copilot";
            icon = " ";
          }
          {
            __unkeyed-1 = "<leader>d";
            group = "Debug";
            icon = " ";
          }
          {
            __unkeyed-1 = "<leader>f";
            group = "Find / Picker";
            icon = " ";
          }
          {
            __unkeyed-1 = "<leader>g";
            group = "Git";
            icon = "󰊢 ";
          }
          {
            __unkeyed-1 = "<leader>l";
            group = "LSP";
            icon = " ";
          }
          {
            __unkeyed-1 = "<leader>r";
            group = "REST";
            icon = "󰆨 ";
          }
          {
            __unkeyed-1 = "<leader>t";
            group = "Test";
            icon = " ";
          }
          {
            __unkeyed-1 = "<leader>u";
            group = "UI Toggle";
            icon = "󰒓 ";
          }
          {
            __unkeyed-1 = "<leader>y";
            group = "Yank";
            icon = "󰆏 ";
          }
        ];
      };
    };

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
        explorer.enabled = true;
        indent.enabled = true;
        input.enabled = true;
        notifier = {
          enabled = true;
          timeout = 3000;
        };
        picker = {
          enabled = true;
          sources.explorer = {
            hidden = true; # show dotfiles
            ignored = false; # hide gitignored
            follow_file = true;
            layout.preset = "sidebar";
            layout.layout.width = 30;
          };
        };
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
