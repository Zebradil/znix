local lint = require("lint")

lint.linters_by_ft = {}

if nixCats("go") then
  lint.linters_by_ft.go = { "golangcilint" }
end

if nixCats("nix") then
  lint.linters_by_ft.nix = { "deadnix", "statix" }
end

vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
  group = vim.api.nvim_create_augroup("nvim_lint", { clear = true }),
  callback = function()
    lint.try_lint()
  end,
})
