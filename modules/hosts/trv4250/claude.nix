{ inputs, ... }:
let
  aicodemetricsdHook = {
    type = "command";
    command = "/usr/local/bin/aicodemetricsd hook claude --hook-input stdin";
  };

  hooks = {
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

  companyProfile = {
    enable = true;
    configDir = ".config/trv-claude";
    command = "trv-claude";
    settings = baseSettings // {
      inherit hooks;
      effortLevel = "high";
      permissions.defaultMode = "default";
    };
  };
in
{
  flake.modules.darwin.trv4250-claude =
    { ... }:
    {
      imports = [ inputs.self.modules.darwin.claude ];

      znix.claude.profiles = {
        personal = {
          enable = true;
          configDir = ".config/personal-claude";
          command = "claude";
          settings = baseSettings // {
            effortLevel = "medium";
          };
        };

        company = companyProfile;

        company-key = companyProfile // {
          command = "trv-claude-key";
          configDir = ".config/trv-claude-key";
          runtimeEnv.ANTHROPIC_API_KEY = "op read 'op://Employee/Anthropic API key/credential'";
        };
      };
    };
}
