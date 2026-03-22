local opt = vim.opt

opt.colorcolumn = "+1"
opt.number = true
opt.relativenumber = false
opt.scrolloff = 8
opt.signcolumn = "yes"
opt.spell = false
opt.termguicolors = true
opt.wrap = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.ignorecase = true
opt.smartcase = true
opt.updatetime = 250
opt.splitbelow = true
opt.splitright = true
opt.undofile = true
opt.clipboard = "unnamedplus"
opt.completeopt = "menu,menuone,noselect"

-- Ansible filetype detection
vim.g.ansible_ftdetect_filename_regex = "\\v^(playbook|site|main|local|requirements|bar)\\.ya?ml$"
