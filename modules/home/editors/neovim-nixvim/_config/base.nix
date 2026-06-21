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
    # -- Folding --
    # Treesitter (plugins-core.nix) supplies foldmethod=expr / foldexpr.
    # Start every buffer with all folds open so `zc` closes only the fold under
    # the cursor instead of every fold at level >= 1.
    foldenable = true;
    foldlevel = 99;
    foldlevelstart = 99;
    colorcolumn = "+1"; # Show a vertical guide 1 column past 'textwidth' to indicate line length
    scrolloff = 8; # Keep 8 lines visible above/below the cursor when scrolling
    signcolumn = "yes"; # Always show the sign column (prevents layout shift from diagnostics/git signs)
    spell = false;
    termguicolors = true; # Enable 24-bit RGB color in the TUI (required by most modern colorschemes)
    wrap = true; # Wrap long lines visually (does not insert actual line breaks)

    # -- Indentation --
    expandtab = true; # Convert tabs to spaces when inserting
    shiftwidth = 2; # Number of spaces used for each step of (auto)indent
    smartindent = true; # Auto-indent new lines based on syntax (e.g., after `{` or keywords)
    tabstop = 2; # Number of spaces a <Tab> character counts for visually

    # -- Search --
    ignorecase = true;
    smartcase = true; # Override 'ignorecase' when the search pattern contains uppercase letters

    # -- Behavior --
    splitbelow = true; # Open horizontal splits below the current window
    splitright = true; # Open vertical splits to the right of the current window
    undofile = true; # Persist undo history to disk so it survives between sessions
    updatetime = 250; # Time in ms before CursorHold fires & swap file is written (snappier diagnostics)

    # -- System Integration --
    autoread = true; # Automatically reload files changed outside of Neovim (required by opencode auto_reload)
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

    -- ── UI toggles (AstroNvim-style <leader>u menu) ──────────────────
    -- Built on Snacks.toggle: each :map() registers the keymap, wires
    -- which-key, and shows a notification with the new state.
    Snacks.toggle.option("spell", { name = "Spellcheck" }):map("<leader>us")
    Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
    Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
    Snacks.toggle.line_number():map("<leader>ul")
    Snacks.toggle.diagnostics():map("<leader>ud")
    Snacks.toggle.treesitter():map("<leader>uT")
    Snacks.toggle.inlay_hints():map("<leader>uh")
    Snacks.toggle.indent():map("<leader>ug")
    Snacks.toggle.dim():map("<leader>uD")
    Snacks.toggle.option("conceallevel", {
      off = 0,
      on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2,
      name = "Conceal",
    }):map("<leader>uc")
    Snacks.toggle.option("background", {
      off = "light",
      on = "dark",
      name = "Dark Background",
    }):map("<leader>ub")

    -- Autoformat (conform): buffer-local flag overrides the global one.
    Snacks.toggle({
      name = "Autoformat (buffer)",
      get = function()
        if vim.b.disable_autoformat ~= nil then
          return not vim.b.disable_autoformat
        end
        return not vim.g.disable_autoformat
      end,
      set = function(state) vim.b.disable_autoformat = not state end,
    }):map("<leader>uf")
    Snacks.toggle({
      name = "Autoformat (global)",
      get = function() return not vim.g.disable_autoformat end,
      set = function(state)
        vim.g.disable_autoformat = not state
        vim.b.disable_autoformat = nil
      end,
    }):map("<leader>uF")

    -- Autopairs (nvim-autopairs).
    Snacks.toggle({
      name = "Autopairs",
      get = function() return not require("nvim-autopairs").state.disabled end,
      set = function(state)
        if state then
          require("nvim-autopairs").enable()
        else
          require("nvim-autopairs").disable()
        end
      end,
    }):map("<leader>ua")

    -- Reference highlight (illuminate).
    Snacks.toggle({
      name = "Reference Highlight",
      get = function() return vim.g.illuminate_enabled ~= false end,
      set = function(state)
        vim.g.illuminate_enabled = state
        if state then
          require("illuminate").resume()
        else
          require("illuminate").pause()
        end
      end,
    }):map("<leader>ur")
  '';

  # ── Extra packages (formatters, linters, runtime deps) ──────────
  extraPackages = with pkgs; [
    # Formatters
    stylua
    gofumpt
    gotools # provides goimports
    nixfmt
    oxfmt
    shfmt

    # Linters
    golangci-lint
    deadnix
    statix
    shellcheck

    # DAP
    delve

    # AI
    opencode

    # TUI
    lazygit

    # Nushell
    nushell
    nufmt

    # Runtime
    nodejs_22
    ripgrep
    fd
  ];
}
