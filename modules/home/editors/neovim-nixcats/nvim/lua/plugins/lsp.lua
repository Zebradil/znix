local lspconfig = require("lspconfig")

-- Common on_attach function
local on_attach = function(_, bufnr)
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
end

-- Build capabilities with blink-cmp support
local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok_blink, blink = pcall(require, "blink.cmp")
if ok_blink then
  capabilities = blink.get_lsp_capabilities(capabilities)
end

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

-- LSP server configurations
local servers = {}

if nixCats("go") then
  servers.gopls = {
    settings = {
      gopls = {
        analyses = { unusedparams = true },
        staticcheck = true,
        gofumpt = true,
      },
    },
  }
end

if nixCats("lua") then
  servers.lua_ls = {
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
  }
end

if nixCats("nix") then
  servers.nixd = {
    settings = {
      nixd = {
        formatting = { command = { "nixfmt" } },
      },
    },
  }
end

if nixCats("yaml") then
  local ok_schema, schemastore = pcall(require, "SchemaStore")
  servers.yamlls = {
    settings = {
      yaml = {
        schemaStore = { enable = false, url = "" },
        schemas = ok_schema and schemastore.yaml.schemas() or {},
        validate = true,
        completion = true,
        hover = true,
      },
    },
  }
end

if nixCats("markdown") then
  servers.marksman = {}
end

if nixCats("terraform") then
  servers.terraformls = {}
  servers.tflint = {}
end

-- Setup all servers
for server, config in pairs(servers) do
  lspconfig[server].setup(vim.tbl_deep_extend("force", {
    capabilities = capabilities,
    on_attach = on_attach,
  }, config))
end

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
