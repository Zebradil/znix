_: {
  plugins = {

    # ─ Git ────────────────────────────────────────────────────────
    gitlinker.enable = true;

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
  };
}
