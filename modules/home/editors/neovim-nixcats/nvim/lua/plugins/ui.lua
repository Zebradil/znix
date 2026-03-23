-- Colorscheme
vim.cmd.colorscheme("tokyonight")

-- mini.icons
require("mini.icons").setup()

-- which-key
require("which-key").setup({})

-- snacks.nvim
require("snacks").setup({
  bigfile = { enabled = true },
  dashboard = {
    enabled = true,
    sections = {
      { section = "header" },
      { section = "keys", gap = 1, padding = 1 },
    },
  },
  indent = { enabled = true },
  input = { enabled = true },
  notifier = {
    enabled = true,
    timeout = 3000,
  },
  picker = { enabled = true },
  quickfile = { enabled = true },
  statuscolumn = { enabled = true },
  words = { enabled = true },
})

-- Snacks picker keymaps
local map = vim.keymap.set
map("n", "<Leader>ff", function() Snacks.picker.files() end, { desc = "Find files" })
map("n", "<Leader>fg", function() Snacks.picker.grep() end, { desc = "Live grep" })
map("n", "<Leader>fb", function() Snacks.picker.buffers() end, { desc = "Find buffers" })
map("n", "<Leader>fh", function() Snacks.picker.help() end, { desc = "Find help" })
map("n", "<Leader>fr", function() Snacks.picker.recent() end, { desc = "Recent files" })
map("n", "<Leader>fk", function() Snacks.picker.keymaps() end, { desc = "Find keymaps" })
map("n", "<Leader>fd", function() Snacks.picker.diagnostics() end, { desc = "Find diagnostics" })
map("n", "<Leader>fs", function() Snacks.picker.lsp_symbols() end, { desc = "Find symbols" })
map("n", "<Leader>fn", function() Snacks.notifier.show_history() end, { desc = "Notification history" })

-- neo-tree
require("neo-tree").setup({
  close_if_last_window = true,
  filesystem = {
    filtered_items = {
      hide_dotfiles = false,
      hide_gitignored = true,
    },
    follow_current_file = { enabled = true },
  },
  window = {
    position = "left",
    width = 30,
  },
})
map("n", "<Leader>e", "<cmd>Neotree toggle<cr>", { desc = "Toggle file tree" })
map("n", "<Leader>o", "<cmd>Neotree focus<cr>", { desc = "Focus file tree" })

-- todo-comments
require("todo-comments").setup({})
map("n", "<Leader>ft", "<cmd>TodoSnacks<cr>", { desc = "Find TODOs" })

-- toggleterm
require("toggleterm").setup({
  size = 20,
  open_mapping = [[<C-\>]],
  direction = "horizontal",
  shell = vim.o.shell,
})
