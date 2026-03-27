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
