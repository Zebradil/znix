{ inputs, ... }:
let
  aicodemetricsdHook = {
    type = "command";
    command = "/usr/local/bin/aicodemetricsd hook claude --hook-input stdin";
  };

  baseSettings = {
    model = "opusplan";
    editorMode = "vim";
    verbose = true;
    remoteControlAtStartup = true;
    agentPushNotifEnabled = true;
    "enabledPlugins" = {
      "gopls-lsp@claude-plugins-official" = true;
    };
  };
in
{
  flake.modules.darwin.trv4250-claude =
    { pkgs, ... }:
    let
      cavemanHooks =
        configDir:
        let
          mkHook = script: {
            type = "command";
            command = ''${pkgs.nodejs}/bin/node "$HOME/${configDir}/hooks/${script}"'';
            timeout = 5;
          };
        in
        {
          SessionStart = [ { hooks = [ (mkHook "caveman-activate.js") ]; } ];
          UserPromptSubmit = [ { hooks = [ (mkHook "caveman-mode-tracker.js") ]; } ];
        };

      mkHooks =
        configDir:
        {
          PostToolUse = [
            {
              matcher = "Write|Edit|MultiEdit";
              hooks = [ aicodemetricsdHook ];
            }
          ];
          PreToolUse = [
            {
              matcher = "Write|Edit|MultiEdit";
              hooks = [ aicodemetricsdHook ];
            }
          ];
          PreCompact = [ { hooks = [ aicodemetricsdHook ]; } ];
          SessionEnd = [ { hooks = [ aicodemetricsdHook ]; } ];
        }
        // (cavemanHooks configDir);

      mkCompanyProfile =
        { configDir, command }:
        {
          enable = true;
          inherit configDir command;
          settings = baseSettings // {
            hooks = mkHooks configDir;
            effortLevel = "high";
            permissions.defaultMode = "default";
          };
        };
    in
    {
      imports = [
        inputs.self.modules.darwin.claude
        inputs.self.modules.darwin.claude-caveman
      ];

      znix.claude = {
        caveman = {
          enable = true;
          profiles = [
            "company"
            "company-key"
          ];
        };

        profiles = {
          personal = {
            enable = true;
            configDir = ".config/personal-claude";
            command = "claude";
            settings = baseSettings // {
              effortLevel = "medium";
            };
          };

          company = mkCompanyProfile {
            configDir = ".config/trv-claude";
            command = "trv-claude";
          };

          company-key =
            (mkCompanyProfile {
              configDir = ".config/trv-claude-key";
              command = "trv-claude-key";
            })
            // {
              runtimeEnv.ANTHROPIC_API_KEY = "op read 'op://Employee/Anthropic API key/credential'";
            };
        };
      };
    };
}
