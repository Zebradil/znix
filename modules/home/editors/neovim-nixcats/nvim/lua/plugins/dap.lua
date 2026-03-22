if not nixCats("go") then return end

local dap = require("dap")
local dapui = require("dapui")

dapui.setup()

-- Auto open/close dapui with debug session
dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

-- Go DAP adapter
require("dap-go").setup({
  dap_configurations = {
    {
      type = "go",
      name = "Attach remote",
      mode = "remote",
      request = "attach",
    },
  },
  delve = {
    path = "dlv",
    initialize_timeout_sec = 20,
    port = "${port}",
    args = {},
  },
})

-- Keymaps
local map = vim.keymap.set
map("n", "<F5>", dap.continue, { desc = "Debug: Start/Continue" })
map("n", "<F11>", dap.step_into, { desc = "Debug: Step Into" })
map("n", "<F10>", dap.step_over, { desc = "Debug: Step Over" })
map("n", "<S-F11>", dap.step_out, { desc = "Debug: Step Out" })
map("n", "<F9>", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
map("n", "<Leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
map("n", "<Leader>dB", function()
  dap.set_breakpoint(vim.fn.input("Condition: "))
end, { desc = "Debug: Conditional Breakpoint" })
map("n", "<Leader>du", dapui.toggle, { desc = "Debug: Toggle UI" })
map("n", "<Leader>dr", dap.repl.open, { desc = "Debug: Open REPL" })
map("n", "<Leader>dl", dap.run_last, { desc = "Debug: Run Last" })
