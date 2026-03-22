if not nixCats("go") then return end

require("neotest").setup({
  adapters = {
    require("neotest-golang")({
      go_test_args = { "-v", "-race", "-timeout=60s" },
      dap_go_enabled = true,
    }),
  },
  output = { open_on_run = false },
  quickfix = { open = false },
})

local map = vim.keymap.set
map("n", "<Leader>tr", function() require("neotest").run.run() end, { desc = "Test: Run nearest" })
map("n", "<Leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, { desc = "Test: Run file" })
map("n", "<Leader>ta", function() require("neotest").run.run(vim.uv.cwd()) end, { desc = "Test: Run all" })
map("n", "<Leader>ts", function() require("neotest").summary.toggle() end, { desc = "Test: Toggle summary" })
map("n", "<Leader>to", function() require("neotest").output_panel.toggle() end, { desc = "Test: Toggle output" })
map("n", "]t", function() require("neotest").jump.next({ status = "failed" }) end, { desc = "Next failed test" })
map("n", "[t", function() require("neotest").jump.prev({ status = "failed" }) end, { desc = "Previous failed test" })
