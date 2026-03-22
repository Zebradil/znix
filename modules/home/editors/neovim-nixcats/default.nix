{ inputs, ... }:
{
  flake-file.inputs = {
    nixCats.url = "github:BirdeeHub/nixCats-nvim";
    # nvim-dap and nvim-lint moved to codeberg which is unreachable; use GitHub mirrors
    "plugins-nvim-dap" = {
      url = "github:mfussenegger/nvim-dap/a9d8cb68ee7184111dc66156c4a2ebabfbe01bc5";
      flake = false;
    };
    "plugins-nvim-lint" = {
      url = "github:mfussenegger/nvim-lint/606b823a57b027502a9ae00978ebf4f5d5158098";
      flake = false;
    };
    "plugins-vim-abolish" = {
      url = "github:tpope/vim-abolish";
      flake = false;
    };
    "plugins-tree-sitter-test_highlights" = {
      url = "github:zebradil/tree-sitter-test_highlights";
      flake = false;
    };
    "plugins-tree-sitter-ytt_annotation" = {
      url = "github:zebradil/tree-sitter-ytt_annotation";
      flake = false;
    };
    "plugins-tree-sitter-queries" = {
      url = "github:zebradil/tree-sitter-queries";
      flake = false;
    };
  };

  flake.modules.homeManager.neovim-nixcats =
    {
      pkgs,
      lib,
      osConfig,
      ...
    }:
    let
      utils = inputs.nixCats.utils;

      dependencyOverlays = [ (utils.standardPluginOverlay inputs) ];

      categoryDefinitions =
        { pkgs, ... }:
        {
          lspsAndRuntimeDeps = {
            general = with pkgs; [
              nodejs_22
              ripgrep
              fd
            ];
            go = with pkgs; [
              gopls
              gofumpt
              gotools
              golangci-lint
              delve
            ];
            lua = with pkgs; [
              lua-language-server
              stylua
            ];
            nix = with pkgs; [
              nixd
              nixfmt
              deadnix
              statix
            ];
            yaml = with pkgs; [ yaml-language-server ];
            markdown = with pkgs; [ marksman ];
            terraform = with pkgs; [
              terraform-ls
              tflint
            ];
          };

          startupPlugins = {
            general = with pkgs.vimPlugins; [
              (nvim-treesitter.withPlugins (
                ps: with ps; [
                  bash
                  dockerfile
                  go
                  gomod
                  gosum
                  gowork
                  hcl
                  helm
                  json
                  just
                  lua
                  make
                  markdown
                  markdown_inline
                  nix
                  python
                  rust
                  terraform
                  toml
                  vim
                  vimdoc
                  yaml
                ]
              ))
              SchemaStore-nvim
              blink-cmp
              conform-nvim
              friendly-snippets
              gitsigns-nvim
              lazydev-nvim
              lsp_signature-nvim
              mini-icons
              neo-tree-nvim
              nui-nvim
              nvim-autopairs
              nvim-lspconfig
              nvim-nio
              nvim-ts-autotag
              nvim-window-picker
              pkgs.neovimPlugins.nvim-lint
              plenary-nvim
              snacks-nvim
              todo-comments-nvim
              toggleterm-nvim
              tokyonight-nvim
              vim-illuminate
              which-key-nvim
            ];
            go = with pkgs.vimPlugins; [
              pkgs.neovimPlugins.nvim-dap
              neotest
              neotest-golang
              nvim-dap-go
              nvim-dap-ui
            ];
            markdown = with pkgs.vimPlugins; [ render-markdown-nvim ];
            copilot = with pkgs.vimPlugins; [
              copilot-lua
              CopilotChat-nvim
            ];
            custom = with pkgs.neovimPlugins; [
              vim-abolish
              tree-sitter-test_highlights
              tree-sitter-ytt_annotation
              tree-sitter-queries
            ];
          };
        };

      packageDefinitions = {
        nvim =
          { ... }:
          {
            settings = {
              wrapRc = true;
              hosts.node.enable = true;
            };
            categories = {
              general = true;
              go = true;
              markdown = true;
              copilot = true;
              custom = true;
              lua = true;
              nix = true;
              yaml = true;
              terraform = true;
            };
          };
      };

      nixCatsBuilder = utils.baseBuilder ./nvim {
        nixpkgs = inputs.nixpkgs;
        system = pkgs.system;
        inherit dependencyOverlays;
        extra_pkg_config = { };
      } categoryDefinitions packageDefinitions;

      nvimPkg = nixCatsBuilder "nvim";

      base = {
        home.packages = [ nvimPkg ];
      };

      impermanence = lib.mkIf osConfig.znix.impermanence.enable {
        home.persistence."/persist".directories = [ ".config/github-copilot" ];
      };
    in
    lib.mkMerge [
      base
      impermanence
    ];
}
