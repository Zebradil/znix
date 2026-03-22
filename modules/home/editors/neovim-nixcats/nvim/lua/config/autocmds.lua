local function augroup(name)
  return vim.api.nvim_create_augroup(name, { clear = true })
end

-- Fix YAML semicolon indent issue
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("yaml_indent_fix"),
  pattern = "yaml",
  callback = function()
    vim.opt_local.indentkeys:remove(":")
    vim.opt_local.indentkeys:remove("<:>")
  end,
  desc = "Fix YAML semicolon indent issue",
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    vim.highlight.on_yank()
  end,
  desc = "Highlight yanked text",
})

-- Restore cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("restore_cursor"),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
  desc = "Restore cursor position",
})

-- Disable spell/numbers in terminal
vim.api.nvim_create_autocmd("TermOpen", {
  group = augroup("terminal_settings"),
  callback = function()
    vim.opt_local.spell = false
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
  end,
})
