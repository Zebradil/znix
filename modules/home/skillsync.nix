_: {
  # Standalone sync tool for private (company) skill repos. Deliberately
  # decoupled from the nix config: sources and target dirs live in a
  # hand-written ~/.config/skillsync/config.yaml that exists only on hosts
  # that need private skills — the public flake never references them.
  # See docs/private-skills.md.
  flake.modules.homeManager.skillsync =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      enabled = lib.filterAttrs (_: p: p.enable) (config.znix.claude.profiles or { });
      skillsync = pkgs.writeShellApplication {
        name = "skillsync";
        runtimeInputs = with pkgs; [
          git
          yq-go
          coreutils
        ];
        text = builtins.readFile ./skillsync/skillsync.sh;
      };
    in
    lib.mkIf (enabled != { }) {
      home.packages = [ skillsync ];
    };
}
