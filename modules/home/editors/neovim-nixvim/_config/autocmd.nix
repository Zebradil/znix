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
      desc = ":PyRun [stdin-file] and <Leader>rr (python buffers)";
      event = [ "FileType" ];
      pattern = [ "python" ];
      callback.__raw = ''
        function(args)
          -- Runs a temp copy of the buffer (or range) rather than the file, so
          -- unsaved and unnamed buffers work and a selection can be dedented.
          local function run(opts)
            local first, last = 0, -1
            if opts.range > 0 then first, last = opts.line1 - 1, opts.line2 end
            local lines = vim.api.nvim_buf_get_lines(args.buf, first, last, false)

            local indent
            for _, l in ipairs(lines) do
              if l:match("%S") then
                local n = #l:match("^%s*")
                indent = indent and math.min(indent, n) or n
              end
            end
            if indent and indent > 0 then
              for i, l in ipairs(lines) do lines[i] = l:sub(indent + 1) end
            end

            local script = vim.fn.tempname() .. ".py"
            vim.fn.writefile(lines, script)
            local cmd = "python3 " .. vim.fn.shellescape(script)
            if opts.args ~= "" then
              cmd = cmd .. " < " .. vim.fn.shellescape(vim.fn.fnamemodify(vim.fn.expand(opts.args), ":p"))
            end

            -- The temp script's dir is sys.path[0]; keep sibling imports working.
            local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(args.buf), ":p:h")
            local pythonpath = vim.env.PYTHONPATH and (dir .. ":" .. vim.env.PYTHONPATH) or dir

            -- One output split: replacing it also kills a still-running script.
            local prev = vim.g.pyrun_buf
            if prev and vim.api.nvim_buf_is_valid(prev) then
              vim.api.nvim_buf_delete(prev, { force = true })
            end
            vim.cmd("botright 15split | enew")
            vim.fn.jobstart(cmd, { term = true, env = { PYTHONPATH = pythonpath } })
            vim.g.pyrun_buf = vim.api.nvim_get_current_buf()
          end

          vim.api.nvim_buf_create_user_command(args.buf, "PyRun", run, {
            range = true,
            nargs = "?",
            complete = "file",
            desc = "Run buffer or range with python3, optional stdin file",
          })
          vim.keymap.set({ "n", "x" }, "<Leader>rr", ":PyRun<CR>", {
            buffer = args.buf,
            silent = true,
            desc = "Run: python buffer/selection",
          })
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
