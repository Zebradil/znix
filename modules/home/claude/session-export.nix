_: {
  flake.modules.homeManager.claude-session-export =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      enabled = lib.filterAttrs (_: p: p.enable) (config.znix.claude.profiles or { });

      # The interpreter is a store path, not whatever `python3` PATH happens to
      # resolve to. Same wrapper shape as worklog-prep: modules/home/claude/scripts/
      # is auto-packaged with writeShellScriptBin, which reads its entries as
      # shell text and so can't host a Python file or interpolate a store path.
      sessionExport = pkgs.writeShellScriptBin "claude-session-export" ''
        exec ${pkgs.python3}/bin/python3 ${./session-export/session-export.py} "$@"
      '';
    in
    lib.mkIf (enabled != { }) {
      home.packages = [ sessionExport ];
    };
}
