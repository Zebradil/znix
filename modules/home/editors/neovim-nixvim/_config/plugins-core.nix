{ pkgs, ... }:
{
  plugins = {

    # ─ Treesitter ─────────────────────────────────────────────────
    treesitter = {
      enable = true;
      folding.enable = true;
      highlight.enable = true;
      indent.enable = true;
      settings = {
        incremental_selection = {
          enable = true;
          keymaps = {
            init_selection = "<C-space>";
            node_incremental = "<C-space>";
            scope_incremental = false;
            node_decremental = "<bs>";
          };
        };
      };
      grammarPackages =
        with pkgs.vimPlugins.nvim-treesitter.builtGrammars;
        [
          bash
          css
          cue
          dockerfile
          go
          gomod
          gosum
          gowork
          hcl
          helm
          html
          http
          javascript
          json
          jsonnet
          just
          kcl
          lua
          make
          markdown
          markdown_inline
          nix
          nu
          pkl
          python
          rust
          starlark
          svelte
          terraform
          toml
          vim
          vimdoc
          yaml
        ]
        ++ [
          # Custom zebradil grammars (pre-compiled)
          pkgs.tree-sitter-test_highlights
          pkgs.tree-sitter-ytt_annotation
        ];
    };

    # ─ LSP ────────────────────────────────────────────────────────
    lsp = {
      enable = true;
      servers = {
        gopls = {
          enable = true;
          settings = {
            gopls = {
              analyses.unusedparams = true;
              staticcheck = true;
              gofumpt = true;
            };
          };
        };
        lua_ls = {
          enable = true;
          settings = {
            Lua = {
              workspace.checkThirdParty = false;
              codeLens.enable = true;
              completion.callSnippet = "Replace";
              doc.privateName = [ "^_" ];
              hint = {
                enable = true;
                setType = false;
                paramType = true;
              };
            };
          };
        };
        nixd = {
          enable = true;
          settings = {
            nixd = {
              # nixd completes by evaluating the expression left of the dot. Values
              # arriving as module lambda args (`pkgs`, `lib` in flake-parts/HM/NixOS
              # modules) have no value it can see, so member completion is empty
              # without this. Registry `nixpkgs` keeps the config portable across repos.
              nixpkgs.expr = ''import (builtins.getFlake "nixpkgs") { }'';
              # Want `config.`/option completion too? Add options.<name>.expr pointing
              # at a real NixOS/home-manager/flake-parts eval (see nixd docs).
              formatting.command = [ "nixfmt" ];
            };
          };
        };
        yamlls = {
          enable = true;
          settings = {
            yaml = {
              schemaStore = {
                enable = false;
                url = "";
              };
              validate = true;
              completion = true;
              hover = true;
            };
          };
        };
        bashls = {
          enable = true;
          filetypes = [
            "sh"
            "bash"
            "zsh"
          ];
        };
        cssls.enable = true;
        cue.enable = true;
        jsonnet_ls.enable = true;
        kcl = {
          enable = true;
          # kcl-language-server (overridden for aarch64-darwin) comes from cli-tools.
          # Setting null stops nixvim pulling the un-overridden pkg that lacks darwin.
          package = null;
        };
        emmet_language_server.enable = true;
        html.enable = true;
        marksman.enable = true;
        nushell.enable = true;
        svelte.enable = true;
        terraformls.enable = true;
        tflint.enable = true;
        rust_analyzer = {
          enable = true;
          installCargo = false;
          installRustc = false;
          settings = {
            check.command = "clippy";
          };
        };
      };
    };

    schemastore = {
      enable = true;
      json.enable = false;
      yaml.enable = true;
    };

    lazydev.enable = true;

    # ─ Formatting ─────────────────────────────────────────────────
    conform-nvim = {
      enable = true;
      settings = {
        formatters_by_ft = {
          lua = [ "stylua" ];
          go = [
            "gofumpt"
            "goimports"
          ];
          nix = [ "nixfmt" ];
          cue = [ "cue_fmt" ];
          jsonnet = [ "jsonnetfmt" ];
          kcl = [ "kcl" ];
          pkl = [ "pkl" ];
          terraform = [ "terraform_fmt" ];
          tf = [ "terraform_fmt" ];
          sh = [ "shfmt" ];
          bash = [ "shfmt" ];
          zsh = [ "shfmt" ];
          nu = [ "nufmt" ];
          yaml = [ "oxfmt" ];
          markdown = [ "oxfmt" ];
          html = [ "oxfmt" ];
          css = [ "oxfmt" ];
          javascript = [ "oxfmt" ];
          rust = [ "rustfmt" ];
          http = [ "kulala-fmt" ];
          rest = [ "kulala-fmt" ];
        };
        # kulala-fmt isn't a conform builtin; define it explicitly. Reads
        # from stdin and prints the formatted buffer to stdout.
        formatters.kulala-fmt = {
          command = "kulala-fmt";
          args = [
            "format"
            "--stdin"
          ];
          stdin = true;
        };
        # Honor the <leader>uf / <leader>uF autoformat toggles. Buffer-local
        # flag wins over the global one; either set disables format-on-save.
        format_on_save.__raw = ''
          function(bufnr)
            if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
              return
            end
            return { timeout_ms = 3200, lsp_fallback = true }
          end
        '';
      };
    };

    # ─ Linting ────────────────────────────────────────────────────
    lint = {
      enable = true;
      lintersByFt = {
        go = [ "golangcilint" ];
        sh = [ "shellcheck" ];
        bash = [ "shellcheck" ];
        zsh = [ "shellcheck" ];
        nix = [
          "deadnix"
          "statix"
        ];
      };
      linters = {
        shellcheck.args = [
          "--shell=bash"
          "--format=json"
          "-"
        ];
      };
      autoCmd.event = [
        "BufWritePost"
        "BufReadPost"
        "InsertLeave"
      ];
    };

    # ─ Completion ─────────────────────────────────────────────────
    blink-cmp = {
      enable = true;
      settings = {
        keymap = {
          preset = "default";
          "<Tab>" = [
            "select_next"
            "fallback"
          ];
          "<S-Tab>" = [
            "select_prev"
            "fallback"
          ];
          "<CR>" = [
            "accept"
            "fallback"
          ];
          "<C-Space>" = [
            "show"
            "show_documentation"
            "hide_documentation"
          ];
          # blink's default preset falls back to other mappings (not neovim's
          # builtin <C-n>), so plain <C-n> stopped triggering completion. Map it
          # to show the menu — the buffer source below gives words-in-buffer.
          "<C-n>" = [
            "show"
            "select_next"
            "fallback"
          ];
          "<C-p>" = [
            "show"
            "select_prev"
            "fallback"
          ];
          "<C-e>" = [ "hide" ];
          "<C-b>" = [
            "scroll_documentation_up"
            "fallback"
          ];
          "<C-f>" = [
            "scroll_documentation_down"
            "fallback"
          ];
        };
        appearance = {
          use_nvim_cmp_as_default = false;
          nerd_font_variant = "mono";
        };
        sources.default = [
          "lsp"
          "path"
          "snippets"
          "buffer"
        ];
        completion = {
          documentation = {
            auto_show = true;
            auto_show_delay_ms = 200;
          };
          ghost_text.enabled = false;
        };
        signature.enabled = true;
      };
    };
  };

  # KCL uses the `.k` extension; neovim doesn't detect it out of the box.
  filetype.extension.k = "kcl";

  # pkl LSP isn't in nvim-lspconfig; wire the native lsp server directly.
  lsp.servers.pkl = {
    enable = true;
    package = pkgs.pkl-lsp;
    config = {
      cmd = [ "pkl-lsp" ];
      filetypes = [ "pkl" ];
      root_markers = [
        "PklProject"
        ".git"
      ];
    };
  };
}
