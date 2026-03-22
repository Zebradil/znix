local conform = require("conform")

conform.setup({
  formatters_by_ft = {
    lua = { "stylua" },
    go = { "gofumpt", "goimports" },
    nix = { "nixfmt" },
    terraform = { "terraform_fmt" },
    tf = { "terraform_fmt" },
    markdown = { "prettier" },
  },
  format_on_save = {
    timeout_ms = 3200,
    lsp_fallback = true,
  },
})

vim.keymap.set({ "n", "v" }, "<Leader>lf", function()
  conform.format({ async = true, lsp_fallback = true })
end, { desc = "Format buffer" })
