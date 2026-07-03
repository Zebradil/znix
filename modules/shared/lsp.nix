{ ... }:
let
  # Shared LSP server map. Single source of truth consumed by both the Claude
  # Code plugin renderer (modules/home/claude) and opencode's native `lsp`
  # config (modules/home/opencode). Binaries are Nix store paths so neither
  # tool ever auto-installs anything. Settings mirror the nixvim LSP config in
  # modules/home/editors/neovim-nixvim/_config/plugins-core.nix.
  #
  # ponytail: values duplicated from nixvim's plugins-core.nix. Unify by making
  # nixvim consume znix.lsp.servers if the drift ever bites.
  lspModule =
    { lib, pkgs, ... }:
    {
      options.znix.lsp.servers = lib.mkOption {
        description = ''
          LSP servers exposed to the AI agents (Claude Code, opencode), keyed by
          a short id. `command` is an absolute store path; nothing is fetched at
          runtime.
        '';
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              command = lib.mkOption {
                type = lib.types.str;
                description = "Absolute path to the language server binary.";
              };
              args = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
              };
              extensions = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                description = "File extension (with dot) -> LSP language id.";
                example = {
                  ".go" = "go";
                };
              };
              settings = lib.mkOption {
                type = lib.types.attrs;
                default = { };
                description = "Server settings (workspace/didChangeConfiguration).";
              };
            };
          }
        );
        default = {
          go = {
            command = "${pkgs.gopls}/bin/gopls";
            extensions = {
              ".go" = "go";
            };
            settings.gopls = {
              analyses.unusedparams = true;
              staticcheck = true;
              gofumpt = true;
            };
          };
          nix = {
            command = "${pkgs.nixd}/bin/nixd";
            extensions = {
              ".nix" = "nix";
            };
            settings.nixd.formatting.command = [ "nixfmt" ];
          };
          rust = {
            command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
            extensions = {
              ".rs" = "rust";
            };
            settings.rust-analyzer.check.command = "clippy";
          };
          lua = {
            command = "${pkgs.lua-language-server}/bin/lua-language-server";
            extensions = {
              ".lua" = "lua";
            };
            settings.Lua = {
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
          yaml = {
            command = "${pkgs.yaml-language-server}/bin/yaml-language-server";
            args = [ "--stdio" ];
            extensions = {
              ".yaml" = "yaml";
              ".yml" = "yaml";
            };
            settings.yaml = {
              schemaStore = {
                enable = false;
                url = "";
              };
              validate = true;
              completion = true;
              hover = true;
            };
          };
          bash = {
            command = "${pkgs.bash-language-server}/bin/bash-language-server";
            args = [ "start" ];
            extensions = {
              ".sh" = "shellscript";
              ".bash" = "shellscript";
              ".zsh" = "shellscript";
            };
          };
          terraform = {
            command = "${pkgs.terraform-ls}/bin/terraform-ls";
            args = [ "serve" ];
            extensions = {
              ".tf" = "terraform";
              ".tfvars" = "terraform";
            };
          };
        };
      };
    };
in
{
  flake.modules.nixos.lsp = lspModule;
  flake.modules.darwin.lsp = lspModule;
}
