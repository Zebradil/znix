# Hyprland

Hyprland config lives in `modules/home/desktop/hyprland/`. Since Hyprland 0.57 the compositor reads only
`~/.config/hypr/hyprland.lua`; the hyprlang `hyprland.conf` is ignored. Home Manager generates the Lua file with
`wayland.windowManager.hyprland.configType = "lua"`.

The standalone tools (hypridle, hyprlock, hyprpaper) still use hyprlang `.conf` files.

## Writing settings

Each `settings.<name>` entry renders as an `hl.<name>(...)` call; a list renders one call per element, and lists from
several modules merge. An entry with `_args` becomes a multi-argument call, and `lib.generators.mkLuaInline` values are
emitted as raw Lua.

`_lua.nix` wraps the common shapes. Import it with `import ./_lua.nix { inherit lib; }`:

```nix
settings.bind = [
  (hl.bind "SUPER + F" "hl.dsp.window.fullscreen()")
  (hl.bindExec "SUPER + E" "hypr-exec kitty -e yazi")
  (hl.bindOpts { repeating = true; locked = true; } "XF86AudioRaiseVolume" (hl.exec "swayosd-client --output-volume raise"))
];
settings.on = [ (hl.onStart "some-daemon") ];  # exec-once equivalent
settings.config.input.repeat_rate = 35;        # merged into one hl.config({...})
```

Key names use `MODS + key` (`"SUPER + SHIFT + code:10"`). Config keys use underscores (`tap_to_click`, not
`tap-to-click`).

## Validating

Hyprland can check a config without starting:

```bash
nix build --no-link --print-out-paths '.#homeConfigurations."zebradil@tuxedo".activationPackage'
Hyprland --verify-config -c <generation>/home-files/.config/hypr/hyprland.lua
```

It catches unknown config keys, unknown key names, and bad arguments to most dispatchers. It does not run bind
callbacks or check arguments that are only read at dispatch time (see `dpms` below).

The Lua API stubs ship at `<hyprland>/share/hypr/stubs/hl.meta.lua`; Home Manager points `~/.config/hypr/.luarc.json`
at them for the Lua language server. The Hyprland source (`src/config/lua/bindings/`) is the reference when the stubs
only say `fun(...)`.

## Gotchas

- **`hyprctl keyword` is gone.** It answers `unknown request`. Use `hyprctl eval '<lua>'` instead, e.g.
  `hyprctl eval 'hl.config({ general = { layout = "master" } })'`.
- **`hyprctl dispatch` takes Lua.** `hyprctl dispatch dpms on` fails with a syntax error; write
  `hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'`.
- **`hl.dsp.dpms` toggles unless given a table.** `hl.dsp.dpms("on")`, or a table with an unknown `action`, silently
  means *toggle* and reports `ok`. Always pass `{ action = "on" | "off" | "toggle" }`. The same parser backs other
  toggle dispatchers such as `hl.dsp.window.float`.
- **`hl.monitor` merges into the existing rule for that output.** hyprlang's `keyword monitor` replaced the whole rule.
  After `hl.monitor({ output = "X", disabled = true })`, a later call without `disabled = false` leaves the monitor
  off; the same holds for `mirror`. `monitor-switch.sh` (`set_monitor`) resets both on every call.
- **Monitor positions:** valid values are `auto`, `auto-{up,down,left,right}`, `auto-center-{up,down,left,right}`, or
  `WxH` coordinates. Combinations such as `auto-down-right` are rejected.
- **Hyprland writes a default `hyprland.lua`** when none exists at startup (it logs `No config file found; attempting
  to generate`). That regular file would block Home Manager's link, so the module sets
  `xdg.configFile."hypr/hyprland.lua".force = true`.
- **Runtime changes are not in the config.** `hyprctl eval` changes (monitor presets, layout switches) live only in
  the running instance; a config reload, e.g. on activation, re-runs `hyprland.lua` from scratch.
  `monitor-switch-default` re-applies the monitor preset after activation.
