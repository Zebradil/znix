-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    autocmds = {
      yaml_indent_fix = {
        {
          event = "FileType",
          pattern = "yaml",
          callback = function()
            vim.opt_local.indentkeys:remove ":"
            vim.opt_local.indentkeys:remove "<:>"
          end,
          desc = "Fix YAML semicolon indent issue",
        },
      },
    },
    -- Configure core features of AstroNvim
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 }, -- set global limits for large files for disabling features like treesitter
      autopairs = false, -- enable autopairs at start
      cmp = true, -- enable completion at start
      diagnostics = { virtual_text = true, virtual_lines = false }, -- diagnostic settings on startup
      highlighturl = true, -- highlight URLs at start
      notifications = true, -- enable notifications at start
    },
    -- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
    diagnostics = {
      virtual_text = true,
      underline = true,
    },
    -- passed to `vim.filetype.add`
    filetypes = {
      -- see `:h vim.filetype.add` for usage
      extension = {
        foo = "fooscript",
      },
      filename = {
        [".foorc"] = "fooscript",
      },
      pattern = {
        [".*/etc/foo/.*"] = "fooscript",
      },
    },
    -- vim options can be configured here
    options = {
      opt = { -- vim.opt.<key>
        colorcolumn = "+1",
        number = true,
        relativenumber = false,
        scrolloff = 8,
        signcolumn = "yes",
        spell = false,
        termguicolors = true,
        wrap = true,
      },
      g = { -- vim.g.<key>
        -- configure global vim variables (vim.g)
        -- NOTE: `mapleader` and `maplocalleader` must be set in the AstroNvim opts or before `lazy.setup`
        -- This can be found in the `lua/lazy_setup.lua` file
        ansible_ftdetect_filename_regex = "\\v^(playbook|site|main|local|requirements|bar)\\.ya?ml$",
      },
    },
    -- Mappings can be configured through AstroCore as well.
    -- NOTE: keycodes follow the casing in the vimdocs. For example, `<Leader>` must be capitalized
    mappings = {
      -- first key is the mode
      n = {
        -- second key is the lefthand side of the map

        -- navigate buffer tabs
        ["]b"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["[b"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },

        -- mappings seen under group name "Buffer"
        ["<Leader>bd"] = {
          function()
            require("astroui.status.heirline").buffer_picker(
              function(bufnr) require("astrocore.buffer").close(bufnr) end
            )
          end,
          desc = "Close buffer from tabline",
        },

        -- tables with just a `desc` key will be registered with which-key if it's installed
        -- this is useful for naming menus
        -- ["<Leader>b"] = { desc = "Buffers" },

        -- setting a mapping to false will disable it
        -- ["<C-S>"] = false,
      },
      v = {
        ["<Leader>64e"] = {
          "y"
            .. ":let was_paste=&paste<CR>"
            .. ":set paste<CR>"
            .. ":let @b=system('base64 --wrap=0', @\")<CR>"
            .. 'gv"bP'
            .. ":if !was_paste|set nopaste|endif<CR><esc>",
          desc = "Base64 encode",
        },
        ["<Leader>64d"] = {
          "y"
            .. ":let was_paste=&paste<CR>"
            .. ":set paste<CR>"
            .. ":let @b=system('base64 --decode --wrap=0', @\")<CR>"
            .. 'gv"bP'
            .. ":if !was_paste|set nopaste|endif<CR><esc>",
          desc = "Base64 decode",
        },
      },
    },
  },
}
