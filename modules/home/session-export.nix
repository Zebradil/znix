_: {
  flake.modules.homeManager.session-export =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      # Installed when any transcript source is configured: Claude profiles
      # (which also cover opencode) or Cursor.
      claudeOn = lib.filterAttrs (_: p: p.enable) (config.znix.claude.profiles or { }) != { };
      cursorOn = config.znix.cursor.enable or false;

      # The interpreter is a store path, not whatever `python3` PATH happens to
      # resolve to. Same wrapper shape as worklog-prep: modules/home/claude/scripts/
      # is auto-packaged with writeShellScriptBin, which reads its entries as
      # shell text and so can't host a Python file or interpolate a store path.
      sessionExport = pkgs.writeShellScriptBin "session-export" ''
        exec ${pkgs.python3}/bin/python3 ${./session-export/session-export.py} "$@"
      '';
    in
    lib.mkIf (claudeOn || cursorOn) {
      home.packages = [ sessionExport ];
    };
}
