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
    {
      options.znix.aiBudget.enable = lib.mkEnableOption "ai-budget spend reporter";

      config = lib.mkIf config.znix.aiBudget.enable {
        home.packages = [
          (pkgs.writers.writePython3Bin "ai-budget" {
            flakeIgnore = [ "E501" ];
          } (builtins.readFile ./ai-budget.py))
        ];
      };
    };
}
