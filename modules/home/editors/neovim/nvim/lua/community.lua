-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",

  { import = "astrocommunity.git.blame-nvim" },
  { import = "astrocommunity.git.gitlinker-nvim" },
  { import = "astrocommunity.git.octo-nvim" },

  { import = "astrocommunity.markdown-and-latex.render-markdown-nvim" },

  { import = "astrocommunity.test.neotest" },

  { import = "astrocommunity.pack.ansible" },
  { import = "astrocommunity.pack.bash" },
  { import = "astrocommunity.pack.docker" },
  { import = "astrocommunity.pack.go" },
  { import = "astrocommunity.pack.golangci-lint" },
  { import = "astrocommunity.pack.helm" },
  { import = "astrocommunity.pack.just" },
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.markdown" },
  { import = "astrocommunity.pack.nix" },
  { import = "astrocommunity.pack.prettier" },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.pack.rust" },
  { import = "astrocommunity.pack.terraform" },
  { import = "astrocommunity.pack.typescript" },
  { import = "astrocommunity.pack.yaml" },

  { import = "astrocommunity.editing-support.zen-mode-nvim" },
  { import = "astrocommunity.editing-support.copilotchat-nvim" },

  { import = "astrocommunity.completion.blink-cmp" },
  -- { import = "astrocommunity.completion.blink-cmp-git" },
  { import = "astrocommunity.completion.copilot-lua-cmp" },
  {
    "copilot.lua",
    opts = {
      suggestion = { auto_trigger = false },
      filetypes = {
        yaml = true,
        markdown = true,
        gitcommit = true,
      },
    },
  },
}
