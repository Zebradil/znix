{ inputs, ... }:
let
  aicodemetricsdHook = {
    type = "command";
    command = "/usr/local/bin/aicodemetricsd hook claude --hook-input stdin";
  };

  aicodemetricsdHooks = {
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

  mkCompanyProfile =
    { configDir, command }:
    {
      enable = true;
      caveman = true;
      ponytail = true;
      inherit configDir command;
      settings = {
        hooks = aicodemetricsdHooks;
        effortLevel = "high";
      };
    };
in
{
  flake.modules.darwin.trv4250-claude =
    { ... }:
    {
      imports = [
        inputs.self.modules.darwin.claude
        inputs.self.modules.darwin.claude-caveman
        inputs.self.modules.darwin.claude-ponytail
      ];

      znix.claude = {
        caveman.enable = true;
        ponytail.enable = true;

        profiles = {
          personal = inputs.self.lib.claude.mkPersonalProfile { };

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
