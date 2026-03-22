-- nvim-autopairs
require("nvim-autopairs").setup({
  check_ts = true,
  ts_config = {
    lua = { "string" },
    javascript = { "template_string" },
  },
})

-- vim-illuminate (highlight word under cursor)
local ok, illuminate = pcall(require, "illuminate")
if ok then
  illuminate.configure({
    delay = 200,
    large_file_cutoff = 10000,
    large_file_overrides = {
      providers = { "lsp" },
    },
  })
end
