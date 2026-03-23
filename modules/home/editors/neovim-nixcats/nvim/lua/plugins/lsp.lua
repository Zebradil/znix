-- Keymaps for LSP buffers
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspKeymaps", { clear = true }),
  callback = function(args)
    local bufnr = args.buf
    local map = function(mode, lhs, rhs, opts)
      opts = vim.tbl_extend("force", { buffer = bufnr, silent = true }, opts or {})
      vim.keymap.set(mode, lhs, rhs, opts)
    end

    map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
    map("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
    map("n", "gr", vim.lsp.buf.references, { desc = "References" })
    map("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })
    map("n", "gy", vim.lsp.buf.type_definition, { desc = "Type definition" })
    map("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
    map("n", "<C-k>", vim.lsp.buf.signature_help, { desc = "Signature help" })
    map("n", "<Leader>la", vim.lsp.buf.code_action, { desc = "Code action" })
    map("v", "<Leader>la", vim.lsp.buf.code_action, { desc = "Code action" })
    map("n", "<Leader>lr", vim.lsp.buf.rename, { desc = "Rename symbol" })
  end,
})

-- Global capabilities with blink-cmp support
local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok_blink, blink = pcall(require, "blink.cmp")
if ok_blink then
  capabilities = blink.get_lsp_capabilities(capabilities)
end
vim.lsp.config("*", { capabilities = capabilities })

-- Diagnostics config
vim.diagnostic.config({
  virtual_text = true,
  underline = true,
  signs = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = "always",
  },
})

-- LSP server configurations and enable list
local servers_to_enable = {}

if nixCats("go") then
  vim.lsp.config("gopls", {
    settings = {
      gopls = {
        analyses = { unusedparams = true },
        staticcheck = true,
        gofumpt = true,
      },
    },
  })
  table.insert(servers_to_enable, "gopls")
end

if nixCats("lua") then
  vim.lsp.config("lua_ls", {
    settings = {
      Lua = {
        workspace = { checkThirdParty = false },
        codeLens = { enable = true },
        completion = { callSnippet = "Replace" },
        doc = { privateName = { "^_" } },
        hint = {
          enable = true,
          setType = false,
          paramType = true,
        },
      },
    },
  })
  table.insert(servers_to_enable, "lua_ls")
end

if nixCats("nix") then
  vim.lsp.config("nixd", {
    settings = {
      nixd = {
        formatting = { command = { "nixfmt" } },
      },
    },
  })
  table.insert(servers_to_enable, "nixd")
end

if nixCats("yaml") then
  local ok_schema, schemastore = pcall(require, "SchemaStore")
  vim.lsp.config("yamlls", {
    settings = {
      yaml = {
        schemaStore = { enable = false, url = "" },
        schemas = ok_schema and schemastore.yaml.schemas() or {},
        validate = true,
        completion = true,
        hover = true,
      },
    },
  })
  table.insert(servers_to_enable, "yamlls")
end

if nixCats("markdown") then
  table.insert(servers_to_enable, "marksman")
end

if nixCats("terraform") then
  table.insert(servers_to_enable, "terraformls")
  table.insert(servers_to_enable, "tflint")
end

vim.lsp.enable(servers_to_enable)

-- lazydev for Lua LSP
if nixCats("lua") then
  require("lazydev").setup({
    library = {
      { path = "${3rd}/luv/library", words = { "vim%.uv" } },
    },
  })
end

-- lsp_signature: show function signature when typing
require("lsp_signature").setup({
  bind = true,
  handler_opts = { border = "rounded" },
  hint_enable = false,
})
