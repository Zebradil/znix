_: {
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

    # ─ Flash ─
    {
      mode = [
        "n"
        "x"
        "o"
      ];
      key = "s";
      action.__raw = ''function() require("flash").jump() end'';
      options.desc = "Flash";
    }
    {
      mode = [
        "n"
        "x"
        "o"
      ];
      key = "S";
      action.__raw = ''function() require("flash").treesitter() end'';
      options.desc = "Flash Treesitter";
    }
    {
      mode = [ "o" ];
      key = "r";
      action.__raw = ''function() require("flash").remote() end'';
      options.desc = "Remote Flash";
    }
    {
      mode = [
        "o"
        "x"
      ];
      key = "R";
      action.__raw = ''function() require("flash").treesitter_search() end'';
      options.desc = "Treesitter Search";
    }
    {
      mode = [ "c" ];
      key = "<c-s>";
      action.__raw = ''function() require("flash").toggle() end'';
      options.desc = "Toggle Flash Search";
    }

    # ─ Aerial ─
    {
      mode = "n";
      key = "<Leader>a";
      action = "<cmd>AerialToggle!<cr>";
      options.desc = "Toggle aerial";
    }
    {
      mode = "n";
      key = "]s";
      action = "<cmd>AerialNext<cr>";
      options.desc = "Next symbol";
    }
    {
      mode = "n";
      key = "[s";
      action = "<cmd>AerialPrev<cr>";
      options.desc = "Previous symbol";
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
      key = "<Leader>fF";
      action.__raw = "function() Snacks.picker.files { hidden = true, ignored = true } end";
      options.desc = "Find all files";
    }
    {
      mode = "n";
      key = "<Leader>fl";
      action.__raw = "function() Snacks.picker.lines() end";
      options.desc = "Find lines";
    }
    {
      mode = "n";
      key = "<Leader>fg";
      action.__raw = "function() Snacks.picker.grep { hidden = true } end";
      options.desc = "Live grep";
    }
    {
      mode = "n";
      key = "<Leader>fc";
      action.__raw = "function() Snacks.picker.grep_word { hidden = true } end";
      options.desc = "Find word under cursor";
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
}
