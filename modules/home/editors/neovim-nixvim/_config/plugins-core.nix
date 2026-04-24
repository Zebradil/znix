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
          dockerfile
          go
          gomod
          gosum
          gowork
          hcl
          helm
          html
          javascript
          json
          just
          lua
          make
          markdown
          markdown_inline
          nix
          nu
          python
          rust
          starlark
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
        bashls.enable = true;
        cssls.enable = true;
        emmet_language_server.enable = true;
        html.enable = true;
        marksman.enable = true;
        nushell.enable = true;
        terraformls.enable = true;
        tflint.enable = true;
      };
    };

    schemastore = {
      enable = true;
      json.enable = false;
      yaml.enable = true;
    };

    lsp-signature = {
      enable = true;
      settings = {
        bind = true;
        handler_opts.border = "rounded";
        hint_enable = false;
      };
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
          terraform = [ "terraform_fmt" ];
          tf = [ "terraform_fmt" ];
          sh = [ "shfmt" ];
          bash = [ "shfmt" ];
          nu = [ "nufmt" ];
          yaml = [ "oxfmt" ];
          markdown = [ "oxfmt" ];
          html = [ "oxfmt" ];
          css = [ "oxfmt" ];
          javascript = [ "oxfmt" ];
        };
        format_on_save = {
          timeout_ms = 3200;
          lsp_fallback = true;
        };
      };
    };

    # ─ Linting ────────────────────────────────────────────────────
    lint = {
      enable = true;
      lintersByFt = {
        go = [ "golangcilint" ];
        sh = [ "shellcheck" ];
        bash = [ "shellcheck" ];
        nix = [
          "deadnix"
          "statix"
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
}
