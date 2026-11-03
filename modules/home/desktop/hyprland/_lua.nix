# Builders for Home Manager's Lua Hyprland config (configType = "lua").
# A `settings.<name>` entry with `_args` renders as `hl.<name>(arg1, arg2, ...)`.
{ lib }:
let
  lua = lib.generators.mkLuaInline;
  toLua = lib.generators.toLua { };
in
rec {
  # `dispatcher` is a raw Lua expression, e.g. "hl.dsp.window.close()".
  bind = keys: dispatcher: {
    _args = [
      keys
      (lua dispatcher)
    ];
  };
  bindOpts = opts: keys: dispatcher: {
    _args = [
      keys
      (lua dispatcher)
      opts
    ];
  };
  exec = cmd: "hl.dsp.exec_cmd(${toLua cmd})";
  bindExec = keys: cmd: bind keys (exec cmd);

  # exec-once equivalent for `settings.on`: runs at compositor start, not on reload.
  onStart = cmd: {
    _args = [
      "hyprland.start"
      (lua "function() hl.exec_cmd(${toLua cmd}) end")
    ];
  };
}
