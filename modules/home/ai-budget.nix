_: {
  # `ai-budget` — month-to-date spend against the company Claude, Cursor and
  # Copilot caps. Swept into every home config via mkHomeManager; inert until a
  # profile sets znix.aiBudget.enable.
  #
  # No vendor exposes a member-scoped usage API, so the script reads the same
  # endpoints their own UIs call, authenticating with credentials each tool
  # already maintains (Claude Code's keychain entry, Cursor's IDE JWT, gh's
  # token). Nothing lands in sops and nothing expires by hand.
  flake.modules.homeManager.ai-budget =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.znix.aiBudget;

      aiBudget = pkgs.writers.writePython3Bin "ai-budget" {
        flakeIgnore = [ "E501" ];
      } (builtins.readFile ./ai-budget.py);
    in
    {
      options.znix.aiBudget = {
        enable = lib.mkEnableOption "ai-budget spend reporter";

        claudeConfigDir = lib.mkOption {
          type = lib.types.str;
          default = ".claude";
          example = ".config/work-claude";
          description = ''
            Claude Code profile directory (relative to $HOME) whose spend cap to
            report. Only the seat-billed OAuth profile has a cap to read; a
            profile driven by ANTHROPIC_API_KEY has no keychain entry and no
            usage endpoint. `--claude-config-dir` still overrides this per call.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [
          # Wrapped rather than baked into the script: the profile dir is
          # per-home config, and argparse takes the last occurrence, so a
          # user-passed --claude-config-dir still wins over the default here.
          (pkgs.writeShellScriptBin "ai-budget" ''
            exec ${aiBudget}/bin/ai-budget \
              --claude-config-dir ${lib.escapeShellArg "${config.home.homeDirectory}/${cfg.claudeConfigDir}"} "$@"
          '')
        ];
      };
    };
}
