{ ... }:
{
  flake.modules.darwin.defaults =
    { ... }:
    {
      system.defaults.dock.autohide = true;
      system.defaults.dock.mru-spaces = false;
      system.defaults.dock.orientation = "right";
      system.defaults.dock.show-recents = false;
      system.defaults.dock.static-only = true;
      system.defaults.dock.tilesize = 32;

      system.defaults.finder.AppleShowAllExtensions = true;
      system.defaults.finder.FXDefaultSearchScope = "SCcf";
      system.defaults.finder.FXPreferredViewStyle = "Nlsv";
      system.defaults.finder.QuitMenuItem = true;
      system.defaults.finder.ShowPathbar = true;
      system.defaults.finder.ShowStatusBar = true;

      system.defaults.trackpad.Clicking = true;
      system.defaults.trackpad.Dragging = true;
      system.defaults.trackpad.TrackpadRightClick = true;
      system.defaults.trackpad.TrackpadThreeFingerDrag = true;

      system.defaults.universalaccess.closeViewScrollWheelToggle = true;
      system.defaults.universalaccess.closeViewZoomFollowsFocus = true;

      system.keyboard.enableKeyMapping = true;

      system.defaults.CustomUserPreferences = {
        NSGlobalDomain = {
          AppleSpacesSwitchOnActivate = true;
          AppleInterfaceStyle = "Dark";
          InitialKeyRepeat = 15;
          KeyRepeat = 2;
          "com.apple.scrollwheel.scaling" = -1;
        };
      };
    };
}
