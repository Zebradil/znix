local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action

config.color_scheme = "ayu"

config.font = wezterm.font("IosevkaTerm NFM")
config.font_size = 14.0
config.cell_width = 0.9
-- On some systems, this causes some characters to elevate over the base line.
-- See https://github.com/wez/wezterm/issues/3893
-- config.line_height = 1.05

config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
-- config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
    left = 10,
    right = 10,
    top = 0,
    bottom = 0,
}

config.unix_domains = {
    {
        name = "unix",
    },
}

-- This causes `wezterm` to act as though it was started as `wezterm connect unix` by default,
-- connecting to the unix domain on startup. If you prefer to connect manually, leave out this line.
config.default_gui_startup_args = { "connect", "unix" }

-- How many lines of scrollback you want to retain per tab
config.scrollback_lines = 10000

-- Credit to https://github.com/wez/wezterm/issues/4429#issuecomment-1774827062
wezterm.on("toggle-colorscheme", function(window, pane)
    local overrides = window:get_config_overrides() or {}
    if not overrides.color_scheme then
        overrides.color_scheme = "Ayu Light (Gogh)"
    else
        overrides.color_scheme = nil
    end
    window:set_config_overrides(overrides)
end)

config.disable_default_key_bindings = true
-- timeout_milliseconds defaults to 1000 and can be omitted
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 2000 }
config.keys = {
    { key = "%", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "+", mods = "CTRL|SHIFT", action = act.IncreaseFontSize },
    { key = "=", mods = "CTRL", action = act.IncreaseFontSize },
    { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
    { key = "0", mods = "CTRL", action = act.ResetFontSize },
    { key = "1", mods = "LEADER", action = act.ActivateTab(0) },
    { key = "2", mods = "LEADER", action = act.ActivateTab(1) },
    { key = "3", mods = "LEADER", action = act.ActivateTab(2) },
    { key = "4", mods = "LEADER", action = act.ActivateTab(3) },
    { key = "5", mods = "LEADER", action = act.ActivateTab(4) },
    { key = "6", mods = "LEADER", action = act.ActivateTab(5) },
    { key = "7", mods = "LEADER", action = act.ActivateTab(6) },
    { key = "8", mods = "LEADER", action = act.ActivateTab(7) },
    { key = "9", mods = "LEADER", action = act.ActivateTab(8) },
    { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
    { key = "Tab", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
    { key = "Tab", mods = "LEADER", action = act.ActivateLastTab },
    { key = "a", mods = "LEADER|CTRL", action = act.SendKey({ key = "a", mods = "CTRL" }) },
    { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
    { key = "c", mods = "SHIFT|CTRL", action = act.CopyTo("Clipboard") },
    { key = "c", mods = "SUPER", action = act.CopyTo("Clipboard") },
    { key = "f", mods = "SHIFT|CTRL", action = act.Search("CurrentSelectionOrEmptyString") },
    { key = "k", mods = "SHIFT|CTRL", action = act.ClearScrollback("ScrollbackOnly") },
    { key = "l", mods = "SHIFT|CTRL", action = act.ShowDebugOverlay },
    { key = "p", mods = "SHIFT|CTRL", action = act.ActivateCommandPalette },
    { key = "r", mods = "SHIFT|CTRL", action = act.ReloadConfiguration },
    { key = "t", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
    { key = "v", mods = "SHIFT|CTRL", action = act.PasteFrom("Clipboard") },
    { key = "v", mods = "SUPER", action = act.PasteFrom("Clipboard") },
    { key = "x", mods = "LEADER", action = act.CloseCurrentTab({ confirm = true }) },
    { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
    { key = '"', mods = "LEADER|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
    { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
    { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
    { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
    { key = "h", mods = "LEADER|CTRL", action = act.AdjustPaneSize({ "Left", 1 }) },
    { key = "l", mods = "LEADER|CTRL", action = act.AdjustPaneSize({ "Right", 1 }) },
    { key = "k", mods = "LEADER|CTRL", action = act.AdjustPaneSize({ "Down", 1 }) },
    { key = "j", mods = "LEADER|CTRL", action = act.AdjustPaneSize({ "Up", 1 }) },
    { key = "t", mods = "LEADER|CTRL", action = act.EmitEvent("toggle-colorscheme") },

    -- defaults
    {
        key = "u",
        mods = "SHIFT|CTRL",
        action = act.CharSelect({ copy_on_select = true, copy_to = "ClipboardAndPrimarySelection" }),
    },
    { key = "x", mods = "SHIFT|CTRL", action = act.ActivateCopyMode },
    { key = "phys:Space", mods = "SHIFT|CTRL", action = act.QuickSelect },
    { key = "PageUp", mods = "SHIFT", action = act.ScrollByPage(-1) },
    { key = "PageUp", mods = "SHIFT|CTRL", action = act.MoveTabRelative(-1) },
    { key = "PageDown", mods = "SHIFT", action = act.ScrollByPage(1) },
    { key = "PageDown", mods = "SHIFT|CTRL", action = act.MoveTabRelative(1) },
    { key = "LeftArrow", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Left") },
    { key = "LeftArrow", mods = "SHIFT|ALT|CTRL", action = act.AdjustPaneSize({ "Left", 1 }) },
    { key = "RightArrow", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Right") },
    { key = "RightArrow", mods = "SHIFT|ALT|CTRL", action = act.AdjustPaneSize({ "Right", 1 }) },
    { key = "UpArrow", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Up") },
    { key = "UpArrow", mods = "SHIFT|ALT|CTRL", action = act.AdjustPaneSize({ "Up", 1 }) },
    { key = "DownArrow", mods = "SHIFT|CTRL", action = act.ActivatePaneDirection("Down") },
    { key = "DownArrow", mods = "SHIFT|ALT|CTRL", action = act.AdjustPaneSize({ "Down", 1 }) },
    { key = "Insert", mods = "SHIFT", action = act.PasteFrom("PrimarySelection") },
    { key = "Insert", mods = "CTRL", action = act.CopyTo("PrimarySelection") },
    { key = "Copy", mods = "NONE", action = act.CopyTo("Clipboard") },
    { key = "Paste", mods = "NONE", action = act.PasteFrom("Clipboard") },
}

config.key_tables = {
    copy_mode = {
        { key = "Tab", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
        { key = "Tab", mods = "SHIFT", action = act.CopyMode("MoveBackwardWord") },
        { key = "Enter", mods = "NONE", action = act.CopyMode("MoveToStartOfNextLine") },
        { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
        { key = "Space", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
        { key = "$", mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
        { key = "$", mods = "SHIFT", action = act.CopyMode("MoveToEndOfLineContent") },
        { key = ",", mods = "NONE", action = act.CopyMode("JumpReverse") },
        { key = "0", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
        { key = ";", mods = "NONE", action = act.CopyMode("JumpAgain") },
        { key = "F", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = false } }) },
        { key = "F", mods = "SHIFT", action = act.CopyMode({ JumpBackward = { prev_char = false } }) },
        { key = "G", mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
        { key = "G", mods = "SHIFT", action = act.CopyMode("MoveToScrollbackBottom") },
        { key = "H", mods = "NONE", action = act.CopyMode("MoveToViewportTop") },
        { key = "H", mods = "SHIFT", action = act.CopyMode("MoveToViewportTop") },
        { key = "L", mods = "NONE", action = act.CopyMode("MoveToViewportBottom") },
        { key = "L", mods = "SHIFT", action = act.CopyMode("MoveToViewportBottom") },
        { key = "M", mods = "NONE", action = act.CopyMode("MoveToViewportMiddle") },
        { key = "M", mods = "SHIFT", action = act.CopyMode("MoveToViewportMiddle") },
        { key = "O", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEndHoriz") },
        { key = "O", mods = "SHIFT", action = act.CopyMode("MoveToSelectionOtherEndHoriz") },
        { key = "T", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = true } }) },
        { key = "T", mods = "SHIFT", action = act.CopyMode({ JumpBackward = { prev_char = true } }) },
        { key = "V", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Line" }) },
        { key = "V", mods = "SHIFT", action = act.CopyMode({ SetSelectionMode = "Line" }) },
        { key = "^", mods = "NONE", action = act.CopyMode("MoveToStartOfLineContent") },
        { key = "^", mods = "SHIFT", action = act.CopyMode("MoveToStartOfLineContent") },
        { key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
        { key = "b", mods = "ALT", action = act.CopyMode("MoveBackwardWord") },
        { key = "b", mods = "CTRL", action = act.CopyMode("PageUp") },
        { key = "c", mods = "CTRL", action = act.CopyMode("Close") },
        { key = "d", mods = "CTRL", action = act.CopyMode({ MoveByPage = 0.5 }) },
        { key = "e", mods = "NONE", action = act.CopyMode("MoveForwardWordEnd") },
        { key = "f", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = false } }) },
        { key = "f", mods = "ALT", action = act.CopyMode("MoveForwardWord") },
        { key = "f", mods = "CTRL", action = act.CopyMode("PageDown") },
        { key = "g", mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
        { key = "g", mods = "CTRL", action = act.CopyMode("Close") },
        { key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
        { key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
        { key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
        { key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
        { key = "m", mods = "ALT", action = act.CopyMode("MoveToStartOfLineContent") },
        { key = "o", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEnd") },
        { key = "q", mods = "NONE", action = act.CopyMode("Close") },
        { key = "t", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = true } }) },
        { key = "u", mods = "CTRL", action = act.CopyMode({ MoveByPage = -0.5 }) },
        { key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
        { key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
        { key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
        {
            key = "y",
            mods = "NONE",
            action = act.Multiple({ { CopyTo = "ClipboardAndPrimarySelection" }, { CopyMode = "Close" } }),
        },
        { key = "PageUp", mods = "NONE", action = act.CopyMode("PageUp") },
        { key = "PageDown", mods = "NONE", action = act.CopyMode("PageDown") },
        { key = "End", mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
        { key = "Home", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
        { key = "LeftArrow", mods = "NONE", action = act.CopyMode("MoveLeft") },
        { key = "LeftArrow", mods = "ALT", action = act.CopyMode("MoveBackwardWord") },
        { key = "RightArrow", mods = "NONE", action = act.CopyMode("MoveRight") },
        { key = "RightArrow", mods = "ALT", action = act.CopyMode("MoveForwardWord") },
        { key = "UpArrow", mods = "NONE", action = act.CopyMode("MoveUp") },
        { key = "DownArrow", mods = "NONE", action = act.CopyMode("MoveDown") },
    },

    search_mode = {
        { key = "Enter", mods = "NONE", action = act.CopyMode("PriorMatch") },
        { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
        { key = "n", mods = "CTRL", action = act.CopyMode("NextMatch") },
        { key = "p", mods = "CTRL", action = act.CopyMode("PriorMatch") },
        { key = "r", mods = "CTRL", action = act.CopyMode("CycleMatchType") },
        { key = "u", mods = "CTRL", action = act.CopyMode("ClearPattern") },
        { key = "PageUp", mods = "NONE", action = act.CopyMode("PriorMatchPage") },
        { key = "PageDown", mods = "NONE", action = act.CopyMode("NextMatchPage") },
        { key = "UpArrow", mods = "NONE", action = act.CopyMode("PriorMatch") },
        { key = "DownArrow", mods = "NONE", action = act.CopyMode("NextMatch") },
    },
}

config.mouse_bindings = {
    -- Change the default click behavior so that it only selects
    -- text and doesn't open hyperlinks
    {
        event = { Up = { streak = 1, button = "Left" } },
        mods = "NONE",
        action = act.CompleteSelection("PrimarySelection"),
    },

    -- and make CTRL-Click open hyperlinks
    {
        event = { Up = { streak = 1, button = "Left" } },
        mods = "CTRL",
        action = act.OpenLinkAtMouseCursor,
    },

    -- Disable the 'Down' event of CTRL-Click to avoid weird program behaviors
    {
        event = { Down = { streak = 1, button = "Left" } },
        mods = "CTRL",
        action = act.Nop,
    },
    -- Scrolling up while holding CTRL increases the font size
    {
        event = { Down = { streak = 1, button = { WheelUp = 1 } } },
        mods = "CTRL",
        action = act.IncreaseFontSize,
    },

    -- Scrolling down while holding CTRL decreases the font size
    {
        event = { Down = { streak = 1, button = { WheelDown = 1 } } },
        mods = "CTRL",
        action = act.DecreaseFontSize,
    },
}

return config
