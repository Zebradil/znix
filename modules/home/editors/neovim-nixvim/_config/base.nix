{ pkgs, ... }:
{
  enable = true;
  defaultEditor = true;

  # ── Global variables ──────────────────────────────────────────────
  globals = {
    mapleader = " ";
    maplocalleader = ",";
  };

  # ── Editor options ────────────────────────────────────────────────
  opts = {
    # -- Line Numbers --
    number = true;
    relativenumber = false;

    # -- Display --
    foldenable = false; # Disable code folding by default
    scrolloff = 8; # Keep 8 lines visible above/below the cursor when scrolling
    signcolumn = "yes"; # Always show the sign column (prevents layout shift from diagnostics/git signs)
    spell = false;
    termguicolors = true; # Enable 24-bit RGB color in the TUI (required by most modern colorschemes)
    wrap = true; # Wrap long lines visually (does not insert actual line breaks)
    colorcolumn = "+1"; # Show a vertical guide 1 column past 'textwidth' to indicate line length

    # -- Indentation --
    expandtab = true; # Convert tabs to spaces when inserting
    shiftwidth = 2; # Number of spaces used for each step of (auto)indent
    tabstop = 2; # Number of spaces a <Tab> character counts for visually
    smartindent = true; # Auto-indent new lines based on syntax (e.g., after `{` or keywords)

    # -- Search --
    ignorecase = true;
    smartcase = true; # Override 'ignorecase' when the search pattern contains uppercase letters

    # -- Behavior --
    updatetime = 250; # Time in ms before CursorHold fires & swap file is written (snappier diagnostics)
    splitbelow = true; # Open horizontal splits below the current window
    splitright = true; # Open vertical splits to the right of the current window
    undofile = true; # Persist undo history to disk so it survives between sessions

    # -- System Integration --
    clipboard = "unnamedplus"; # Use the system clipboard for all yank/delete/paste operations

    # -- Completion --
    completeopt = "menu,menuone,noselect";
    # menu      → show a popup menu for completions
    # menuone   → show the menu even when there's only one match
    # noselect  → don't auto-select the first entry (lets you confirm explicitly)
  };

  # ── Diagnostics ──────────────────────────────────────────────────
  diagnostic = {
    settings = {
      virtual_text = true;
      underline = true;
      signs = true;
      update_in_insert = false;
      severity_sort = true;
      float = {
        border = "rounded";
        source = true;
      };
    };
  };

  # ── Colorscheme ──────────────────────────────────────────────────
  colorschemes.tokyonight.enable = true;

  # ── Extra Lua config (for plugins without nixvim modules) ────────
  extraConfigLua = ''
    -- CopilotChat setup
    require("CopilotChat").setup({
      window = {
        layout = "float",
        width = 0.8,
        height = 0.8,
        border = "rounded",
      },
      show_help = true,
      question_header = "  User ",
      answer_header = "  Copilot ",
    })

    -- DAP UI auto open/close
    local dap, dapui = require("dap"), require("dapui")
    dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
    dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
    dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
  '';

  # ── Extra packages (formatters, linters, runtime deps) ──────────
  extraPackages = with pkgs; [
    # Formatters
    stylua
    gofumpt
    gotools # provides goimports
    nixfmt
    nodePackages.prettier

    # Linters
    golangci-lint
    deadnix
    statix

    # DAP
    delve

    # Runtime
    nodejs_22
    ripgrep
    fd
  ];
}
