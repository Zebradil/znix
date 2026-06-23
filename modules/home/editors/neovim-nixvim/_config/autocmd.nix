_: {
  # ── Autocommands ─────────────────────────────────────────────────
  autoCmd = [
    {
      desc = "Fix YAML semicolon indent issue";
      event = [ "FileType" ];
      pattern = [ "yaml" ];
      callback.__raw = ''
        function()
          vim.opt_local.indentkeys:remove(":")
          vim.opt_local.indentkeys:remove("<:>")
        end
      '';
    }
    {
      desc = "Highlight yanked text";
      event = [ "TextYankPost" ];
      callback.__raw = "function() vim.highlight.on_yank() end";
    }
    {
      desc = "Restore cursor position";
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
    }
    {
      desc = "kulala REST client keymaps (http buffers)";
      event = [ "FileType" ];
      pattern = [ "http" ];
      callback.__raw = ''
        function(args)
          local k = require("kulala")
          local map = function(lhs, fn, desc)
            vim.keymap.set("n", lhs, fn, { buffer = args.buf, desc = desc })
          end
          map("<Leader>rr", k.run, "REST: run request")
          map("<Leader>ra", k.run_all, "REST: run all in file")
          map("<Leader>rp", k.replay, "REST: replay last")
          map("<Leader>rt", k.toggle_view, "REST: toggle body/headers")
          map("<Leader>rc", k.copy, "REST: copy as curl")
          map("<Leader>rq", k.close, "REST: close response")
          map("]r", k.jump_next, "REST: next request")
          map("[r", k.jump_prev, "REST: previous request")
        end
      '';
    }
    {
      desc = "Disable spell/numbers in terminal";
      event = [ "TermOpen" ];
      callback.__raw = ''
        function()
          vim.opt_local.spell = false
          vim.opt_local.number = false
          vim.opt_local.relativenumber = false
        end
      '';
    }
  ];
}
