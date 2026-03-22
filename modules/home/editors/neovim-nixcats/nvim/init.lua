-- Set leader keys before loading plugins
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Load core config
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Load plugins
require("plugins.ui")
require("plugins.editor")
require("plugins.git")
require("plugins.lsp")
require("plugins.completion")
require("plugins.treesitter")
require("plugins.formatting")
require("plugins.linting")
require("plugins.dap")
require("plugins.test")
require("plugins.copilot")
require("plugins.treesitter-custom")
