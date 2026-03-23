{ pkgs, inputs, ... }:
{
  # ── Global variables ──────────────────────────────────────────────
  globals = {
    mapleader = " ";
    maplocalleader = ",";
  };

  # ── Editor options ────────────────────────────────────────────────
  opts = {
    number = true;
    relativenumber = false;
    scrolloff = 8;
    signcolumn = "yes";
    spell = false;
    termguicolors = true;
    wrap = true;
    expandtab = true;
    shiftwidth = 2;
    tabstop = 2;
    smartindent = true;
    ignorecase = true;
    smartcase = true;
    updatetime = 250;
    splitbelow = true;
    splitright = true;
    undofile = true;
    clipboard = "unnamedplus";
    completeopt = "menu,menuone,noselect";
    colorcolumn = "+1";
  };

  # ── Diagnostics ──────────────────────────────────────────────────
  diagnostics = {
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

  # ── Colorscheme ──────────────────────────────────────────────────
  colorschemes.tokyonight.enable = true;

  # ── Plugins ──────────────────────────────────────────────────────
  plugins = {

    # ─ Treesitter ─────────────────────────────────────────────────
    treesitter = {
      enable = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
        incremental_selection = {
          enable = true;
          keymaps = {
            init_selection = "<C-space>";
            node_incremental = "<C-space>";
            scope_incremental = false;
            node_decremental = "<bs>";
          };
        };
      };
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        bash
        dockerfile
        go
        gomod
        gosum
        gowork
        hcl
        helm
        json
        just
        lua
        make
        markdown
        markdown_inline
        nix
        python
        rust
        terraform
        toml
        vim
        vimdoc
        yaml
      ];
    };

    # ─ LSP ────────────────────────────────────────────────────────
    lsp = {
      enable = true;
      servers = {
        gopls = {
          enable = true;
          settings = {
            gopls = {
              analyses.unusedparams = true;
              staticcheck = true;
              gofumpt = true;
            };
          };
        };
        lua_ls = {
          enable = true;
          settings = {
            Lua = {
              workspace.checkThirdParty = false;
              codeLens.enable = true;
              completion.callSnippet = "Replace";
              doc.privateName = [ "^_" ];
              hint = {
                enable = true;
                setType = false;
                paramType = true;
              };
            };
          };
        };
        nixd = {
          enable = true;
          settings = {
            nixd = {
              formatting.command = [ "nixfmt" ];
            };
          };
        };
        yamlls = {
          enable = true;
          settings = {
            yaml = {
              schemaStore = {
                enable = false;
                url = "";
              };
              validate = true;
              completion = true;
              hover = true;
            };
          };
        };
        marksman.enable = true;
        terraformls.enable = true;
        tflint.enable = true;
      };
    };

    schemastore = {
      enable = true;
      yaml.enable = true;
    };

    lsp-signature = {
      enable = true;
      settings = {
        bind = true;
        handler_opts.border = "rounded";
        hint_enable = false;
      };
    };

    lazydev.enable = true;

    # ─ Formatting ─────────────────────────────────────────────────
    conform-nvim = {
      enable = true;
      settings = {
        formatters_by_ft = {
          lua = [ "stylua" ];
          go = [
            "gofumpt"
            "goimports"
          ];
          nix = [ "nixfmt" ];
          terraform = [ "terraform_fmt" ];
          tf = [ "terraform_fmt" ];
          markdown = [ "prettier" ];
        };
        format_on_save = {
          timeout_ms = 3200;
          lsp_fallback = true;
        };
      };
    };

    # ─ Linting ────────────────────────────────────────────────────
    lint = {
      enable = true;
      lintersByFt = {
        go = [ "golangcilint" ];
        nix = [
          "deadnix"
          "statix"
        ];
      };
      autoCmd.event = [
        "BufWritePost"
        "BufReadPost"
        "InsertLeave"
      ];
    };

    # ─ Completion ─────────────────────────────────────────────────
    blink-cmp = {
      enable = true;
      settings = {
        keymap = {
          preset = "default";
          "<Tab>" = [
            "select_next"
            "fallback"
          ];
          "<S-Tab>" = [
            "select_prev"
            "fallback"
          ];
          "<CR>" = [
            "accept"
            "fallback"
          ];
          "<C-Space>" = [
            "show"
            "show_documentation"
            "hide_documentation"
          ];
          "<C-e>" = [ "hide" ];
          "<C-b>" = [
            "scroll_documentation_up"
            "fallback"
          ];
          "<C-f>" = [
            "scroll_documentation_down"
            "fallback"
          ];
        };
        appearance = {
          use_nvim_cmp_as_default = false;
          nerd_font_variant = "mono";
        };
        sources.default = [
          "lsp"
          "path"
          "snippets"
          "buffer"
        ];
        completion = {
          documentation = {
            auto_show = true;
            auto_show_delay_ms = 200;
          };
          ghost_text.enabled = false;
        };
        signature.enabled = true;
      };
    };

    # ─ UI ─────────────────────────────────────────────────────────
    neo-tree = {
      enable = true;
      closeIfLastWindow = true;
      filesystem = {
        filteredItems = {
          hideDotfiles = false;
          hideGitignored = true;
        };
        followCurrentFile.enabled = true;
      };
      window = {
        position = "left";
        width = 30;
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
            { section = "startup"; }
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

    # ─ Git ────────────────────────────────────────────────────────
    gitsigns = {
      enable = true;
      settings = {
        signs = {
          add.text = "▎";
          change.text = "▎";
          delete.text = "";
          topdelete.text = "";
          changedelete.text = "▎";
        };
        on_attach.__raw = ''
          function(bufnr)
            local gs = package.loaded.gitsigns
            local map = function(mode, lhs, rhs, opts)
              opts = vim.tbl_extend("force", { buffer = bufnr }, opts or {})
              vim.keymap.set(mode, lhs, rhs, opts)
            end

            -- Navigation
            map("n", "]g", function()
              if vim.wo.diff then return "]g" end
              vim.schedule(function() gs.next_hunk() end)
              return "<Ignore>"
            end, { expr = true, desc = "Next git hunk" })
            map("n", "[g", function()
              if vim.wo.diff then return "[g" end
              vim.schedule(function() gs.prev_hunk() end)
              return "<Ignore>"
            end, { expr = true, desc = "Previous git hunk" })

            -- Actions
            map("n", "<Leader>gs", gs.stage_hunk, { desc = "Stage hunk" })
            map("n", "<Leader>gr", gs.reset_hunk, { desc = "Reset hunk" })
            map("v", "<Leader>gs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Stage hunk" })
            map("v", "<Leader>gr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Reset hunk" })
            map("n", "<Leader>gS", gs.stage_buffer, { desc = "Stage buffer" })
            map("n", "<Leader>gR", gs.reset_buffer, { desc = "Reset buffer" })
            map("n", "<Leader>gp", gs.preview_hunk, { desc = "Preview hunk" })
            map("n", "<Leader>gb", function() gs.blame_line({ full = true }) end, { desc = "Blame line" })
            map("n", "<Leader>gd", gs.diffthis, { desc = "Diff this" })
          end
        '';
      };
    };

    # ─ Copilot ────────────────────────────────────────────────────
    copilot-lua = {
      enable = true;
      settings = {
        suggestion = {
          enabled = true;
          auto_trigger = false;
          keymap = {
            accept = "<M-l>";
            accept_word = false;
            accept_line = false;
            next = "<M-]>";
            prev = "<M-[>";
            dismiss = "<C-]>";
          };
        };
        panel.enabled = false;
        filetypes = {
          yaml = true;
          markdown = true;
          gitcommit = true;
          "*" = true;
        };
      };
    };

    # ─ DAP ────────────────────────────────────────────────────────
    dap.enable = true;
    dap-go.enable = true;
    dap-ui.enable = true;

    # ─ Testing ────────────────────────────────────────────────────
    neotest = {
      enable = true;
      adapters = {
        golang = {
          enable = true;
          settings = {
            go_test_args = [
              "-v"
              "-race"
              "-timeout=60s"
            ];
            dap_go_enabled = true;
          };
        };
      };
      settings = {
        output.open_on_run = false;
        quickfix.open = false;
      };
    };
  };

  # ── Extra plugins (no native nixvim module) ──────────────────────
  extraPlugins = with pkgs.vimPlugins; [
    # CopilotChat
    CopilotChat-nvim

    # vim-abolish
    (pkgs.vimUtils.buildVimPlugin {
      name = "vim-abolish";
      src = inputs.plugins-vim-abolish;
    })

    # Custom treesitter grammars
    (pkgs.vimUtils.buildVimPlugin {
      name = "tree-sitter-test_highlights";
      src = inputs.plugins-tree-sitter-test_highlights;
    })
    (pkgs.vimUtils.buildVimPlugin {
      name = "tree-sitter-ytt_annotation";
      src = inputs.plugins-tree-sitter-ytt_annotation;
    })
    (pkgs.vimUtils.buildVimPlugin {
      name = "tree-sitter-queries";
      src = inputs.plugins-tree-sitter-queries;
    })
  ];

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

  # ── Keymaps ──────────────────────────────────────────────────────
  keymaps = [
    # ─ Buffer navigation ─
    {
      mode = "n";
      key = "]b";
      action = "<cmd>bnext<cr>";
      options.desc = "Next buffer";
    }
    {
      mode = "n";
      key = "[b";
      action = "<cmd>bprevious<cr>";
      options.desc = "Previous buffer";
    }
    {
      mode = "n";
      key = "<Leader>bd";
      action = "<cmd>bdelete<cr>";
      options.desc = "Close buffer";
    }

    # ─ Window navigation ─
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
      options.desc = "Move to left window";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
      options.desc = "Move to lower window";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
      options.desc = "Move to upper window";
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
      options.desc = "Move to right window";
    }

    # ─ Save / quit ─
    {
      mode = "n";
      key = "<Leader>w";
      action = "<cmd>w<cr>";
      options.desc = "Save file";
    }
    {
      mode = "n";
      key = "<Leader>q";
      action = "<cmd>q<cr>";
      options.desc = "Quit";
    }

    # ─ Clear search highlight ─
    {
      mode = "n";
      key = "<Esc>";
      action = "<cmd>nohlsearch<cr>";
      options.desc = "Clear search highlight";
    }

    # ─ Diagnostic navigation ─
    {
      mode = "n";
      key = "]d";
      action.__raw = "vim.diagnostic.goto_next";
      options.desc = "Next diagnostic";
    }
    {
      mode = "n";
      key = "[d";
      action.__raw = "vim.diagnostic.goto_prev";
      options.desc = "Previous diagnostic";
    }
    {
      mode = "n";
      key = "<Leader>ld";
      action.__raw = "vim.diagnostic.open_float";
      options.desc = "Line diagnostics";
    }
    {
      mode = "n";
      key = "<Leader>lq";
      action.__raw = "vim.diagnostic.setloclist";
      options.desc = "Diagnostics to loclist";
    }

    # ─ LSP ─
    {
      mode = "n";
      key = "gd";
      action.__raw = "vim.lsp.buf.definition";
      options.desc = "Go to definition";
    }
    {
      mode = "n";
      key = "gD";
      action.__raw = "vim.lsp.buf.declaration";
      options.desc = "Go to declaration";
    }
    {
      mode = "n";
      key = "gr";
      action.__raw = "vim.lsp.buf.references";
      options.desc = "References";
    }
    {
      mode = "n";
      key = "gi";
      action.__raw = "vim.lsp.buf.implementation";
      options.desc = "Go to implementation";
    }
    {
      mode = "n";
      key = "gy";
      action.__raw = "vim.lsp.buf.type_definition";
      options.desc = "Type definition";
    }
    {
      mode = "n";
      key = "K";
      action.__raw = "vim.lsp.buf.hover";
      options.desc = "Hover documentation";
    }
    {
      mode = "n";
      key = "<C-k>";
      action.__raw = "vim.lsp.buf.signature_help";
      options.desc = "Signature help";
    }
    {
      mode = [
        "n"
        "v"
      ];
      key = "<Leader>la";
      action.__raw = "vim.lsp.buf.code_action";
      options.desc = "Code action";
    }
    {
      mode = "n";
      key = "<Leader>lr";
      action.__raw = "vim.lsp.buf.rename";
      options.desc = "Rename symbol";
    }

    # ─ Formatting ─
    {
      mode = [
        "n"
        "v"
      ];
      key = "<Leader>lf";
      action.__raw = ''
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end
      '';
      options.desc = "Format buffer";
    }

    # ─ Neo-tree ─
    {
      mode = "n";
      key = "<Leader>e";
      action = "<cmd>Neotree toggle<cr>";
      options.desc = "Toggle file tree";
    }
    {
      mode = "n";
      key = "<Leader>o";
      action = "<cmd>Neotree focus<cr>";
      options.desc = "Focus file tree";
    }

    # ─ Snacks picker ─
    {
      mode = "n";
      key = "<Leader>ff";
      action.__raw = "function() Snacks.picker.files() end";
      options.desc = "Find files";
    }
    {
      mode = "n";
      key = "<Leader>fg";
      action.__raw = "function() Snacks.picker.grep() end";
      options.desc = "Live grep";
    }
    {
      mode = "n";
      key = "<Leader>fb";
      action.__raw = "function() Snacks.picker.buffers() end";
      options.desc = "Find buffers";
    }
    {
      mode = "n";
      key = "<Leader>fh";
      action.__raw = "function() Snacks.picker.help() end";
      options.desc = "Find help";
    }
    {
      mode = "n";
      key = "<Leader>fr";
      action.__raw = "function() Snacks.picker.recent() end";
      options.desc = "Recent files";
    }
    {
      mode = "n";
      key = "<Leader>fk";
      action.__raw = "function() Snacks.picker.keymaps() end";
      options.desc = "Find keymaps";
    }
    {
      mode = "n";
      key = "<Leader>fd";
      action.__raw = "function() Snacks.picker.diagnostics() end";
      options.desc = "Find diagnostics";
    }
    {
      mode = "n";
      key = "<Leader>fs";
      action.__raw = "function() Snacks.picker.lsp_symbols() end";
      options.desc = "Find symbols";
    }
    {
      mode = "n";
      key = "<Leader>fn";
      action.__raw = "function() Snacks.notifier.show_history() end";
      options.desc = "Notification history";
    }
    {
      mode = "n";
      key = "<Leader>ft";
      action = "<cmd>TodoSnacks<cr>";
      options.desc = "Find TODOs";
    }

    # ─ Base64 encode/decode (visual mode) ─
    {
      mode = "v";
      key = "<Leader>64e";
      action = "y:let was_paste=&paste<CR>:set paste<CR>:let @b=system('base64 --wrap=0', @\")<CR>gv\"bP:if !was_paste|set nopaste|endif<CR><esc>";
      options.desc = "Base64 encode";
    }
    {
      mode = "v";
      key = "<Leader>64d";
      action = "y:let was_paste=&paste<CR>:set paste<CR>:let @b=system('base64 --decode --wrap=0', @\")<CR>gv\"bP:if !was_paste|set nopaste|endif<CR><esc>";
      options.desc = "Base64 decode";
    }

    # ─ Copilot Chat ─
    {
      mode = "n";
      key = "<Leader>cc";
      action = "<cmd>CopilotChatToggle<cr>";
      options.desc = "Copilot Chat Toggle";
    }
    {
      mode = "v";
      key = "<Leader>ce";
      action = "<cmd>CopilotChatExplain<cr>";
      options.desc = "Copilot Explain";
    }
    {
      mode = "v";
      key = "<Leader>cf";
      action = "<cmd>CopilotChatFix<cr>";
      options.desc = "Copilot Fix";
    }
    {
      mode = "v";
      key = "<Leader>cr";
      action = "<cmd>CopilotChatReview<cr>";
      options.desc = "Copilot Review";
    }
    {
      mode = "v";
      key = "<Leader>cd";
      action = "<cmd>CopilotChatDocs<cr>";
      options.desc = "Copilot Docs";
    }
    {
      mode = "n";
      key = "<Leader>cp";
      action.__raw = ''
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.snacks").pick(actions.prompt_actions())
        end
      '';
      options.desc = "Copilot Prompt actions";
    }

    # ─ DAP ─
    {
      mode = "n";
      key = "<F5>";
      action.__raw = "function() require('dap').continue() end";
      options.desc = "Debug: Start/Continue";
    }
    {
      mode = "n";
      key = "<F11>";
      action.__raw = "function() require('dap').step_into() end";
      options.desc = "Debug: Step Into";
    }
    {
      mode = "n";
      key = "<F10>";
      action.__raw = "function() require('dap').step_over() end";
      options.desc = "Debug: Step Over";
    }
    {
      mode = "n";
      key = "<S-F11>";
      action.__raw = "function() require('dap').step_out() end";
      options.desc = "Debug: Step Out";
    }
    {
      mode = "n";
      key = "<F9>";
      action.__raw = "function() require('dap').toggle_breakpoint() end";
      options.desc = "Debug: Toggle Breakpoint";
    }
    {
      mode = "n";
      key = "<Leader>db";
      action.__raw = "function() require('dap').toggle_breakpoint() end";
      options.desc = "Debug: Toggle Breakpoint";
    }
    {
      mode = "n";
      key = "<Leader>dB";
      action.__raw = ''
        function()
          require("dap").set_breakpoint(vim.fn.input("Condition: "))
        end
      '';
      options.desc = "Debug: Conditional Breakpoint";
    }
    {
      mode = "n";
      key = "<Leader>du";
      action.__raw = "function() require('dapui').toggle() end";
      options.desc = "Debug: Toggle UI";
    }
    {
      mode = "n";
      key = "<Leader>dr";
      action.__raw = "function() require('dap').repl.open() end";
      options.desc = "Debug: Open REPL";
    }
    {
      mode = "n";
      key = "<Leader>dl";
      action.__raw = "function() require('dap').run_last() end";
      options.desc = "Debug: Run Last";
    }

    # ─ Neotest ─
    {
      mode = "n";
      key = "<Leader>tr";
      action.__raw = "function() require('neotest').run.run() end";
      options.desc = "Test: Run nearest";
    }
    {
      mode = "n";
      key = "<Leader>tf";
      action.__raw = "function() require('neotest').run.run(vim.fn.expand('%')) end";
      options.desc = "Test: Run file";
    }
    {
      mode = "n";
      key = "<Leader>ta";
      action.__raw = "function() require('neotest').run.run(vim.uv.cwd()) end";
      options.desc = "Test: Run all";
    }
    {
      mode = "n";
      key = "<Leader>ts";
      action.__raw = "function() require('neotest').summary.toggle() end";
      options.desc = "Test: Toggle summary";
    }
    {
      mode = "n";
      key = "<Leader>to";
      action.__raw = "function() require('neotest').output_panel.toggle() end";
      options.desc = "Test: Toggle output";
    }
    {
      mode = "n";
      key = "]t";
      action.__raw = "function() require('neotest').jump.next({ status = 'failed' }) end";
      options.desc = "Next failed test";
    }
    {
      mode = "n";
      key = "[t";
      action.__raw = "function() require('neotest').jump.prev({ status = 'failed' }) end";
      options.desc = "Previous failed test";
    }
  ];

  # ── Autocommands ─────────────────────────────────────────────────
  autoCmd = [
    {
      event = [ "FileType" ];
      pattern = [ "yaml" ];
      callback.__raw = ''
        function()
          vim.opt_local.indentkeys:remove(":")
          vim.opt_local.indentkeys:remove("<:>")
        end
      '';
      desc = "Fix YAML semicolon indent issue";
    }
    {
      event = [ "TextYankPost" ];
      callback.__raw = "function() vim.highlight.on_yank() end";
      desc = "Highlight yanked text";
    }
    {
      event = [ "BufReadPost" ];
      callback.__raw = ''
        function()
          local mark = vim.api.nvim_buf_get_mark(0, '"')
          local lcount = vim.api.nvim_buf_line_count(0)
          if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
          end
        end
      '';
      desc = "Restore cursor position";
    }
    {
      event = [ "TermOpen" ];
      callback.__raw = ''
        function()
          vim.opt_local.spell = false
          vim.opt_local.number = false
          vim.opt_local.relativenumber = false
        end
      '';
      desc = "Disable spell/numbers in terminal";
    }
  ];
}
