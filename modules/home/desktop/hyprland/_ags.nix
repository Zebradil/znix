{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = builtins.fromJSON (builtins.readFile ./shell-theme.json);
  astalPackages = with pkgs.astal; [
    gjs
    io
    astal3
    hyprland
    tray
    network
    bluetooth
    battery
    wireplumber
    notifd
    mpris
  ];
  giPackages = astalPackages ++ [
    pkgs.networkmanager
    pkgs.wireplumber
    pkgs.gnome-bluetooth
    pkgs.upower
  ];
  notifdExe = lib.getExe' pkgs.astal.notifd "astal-notifd";
  notifdSchemaDir = "${pkgs.astal.notifd}/share/gsettings-schemas/${pkgs.astal.notifd.name}/glib-2.0/schemas";

  giTypelibPath = lib.makeSearchPath "lib/girepository-1.0" giPackages;
  xdgDataDirs = lib.concatStringsSep ":" [
    "${xdgDataDirsBase}"
    "/run/current-system/sw/share"
    "%h/.nix-profile/share"
  ];
  xdgDataDirsBase = lib.makeSearchPath "share" giPackages;

  themeJson = builtins.toJSON {
    inherit (theme) radius margin barHeight;
    font = theme.font;
    colors = theme.colors;
  };
in
lib.mkIf (config.znix.desktop.hyprland.shellPreset == "ags") {
  home.packages =
    with pkgs;
    [
      ags
    ]
    ++ astalPackages
    ++ [
      bluez
      blueman
      networkmanager
      pavucontrol
    ];

  home.file.".config/ags/app.ts".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/app.ts";
  home.file.".config/ags/env.d.ts".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/env.d.ts";
  home.file.".config/ags/tsconfig.json".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/tsconfig.json";
  home.file.".config/ags/package.json".text = builtins.toJSON {
    name = "znix-ags-shell";
    dependencies = {
      astal = "${pkgs.astal.gjs}/share/astal/gjs";
    };
  };
  home.file.".config/ags/style.scss".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/style.scss";
  home.file.".config/ags/lib/theme.ts".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/lib/theme.ts";
  home.file.".config/ags/widgets/bar.tsx".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/widgets/bar.tsx";
  home.file.".config/ags/widgets/workspaces.tsx".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/widgets/workspaces.tsx";
  home.file.".config/ags/widgets/tray.tsx".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/widgets/tray.tsx";
  home.file.".config/ags/widgets/audio.tsx".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/widgets/audio.tsx";
  home.file.".config/ags/widgets/network.tsx".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/widgets/network.tsx";
  home.file.".config/ags/widgets/battery.tsx".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/widgets/battery.tsx";
  home.file.".config/ags/widgets/bluetooth.tsx".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/widgets/bluetooth.tsx";
  home.file.".config/ags/widgets/clock.tsx".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/widgets/clock.tsx";
  home.file.".config/ags/widgets/notifications.tsx".source =
    config.znix.mkRepoLink "modules/home/desktop/hyprland/ags/widgets/notifications.tsx";
  home.file.".config/ags/theme.json".text = themeJson;

  systemd.user.services.ags-shell = {
    Unit = {
      Description = "AGS shell";
      PartOf = [ "graphical-session.target" ];
      After = [
        "graphical-session.target"
        "astal-notifd.service"
      ];
      Wants = [ "astal-notifd.service" ];
    };
    Service = {
      Environment = [
        "GI_TYPELIB_PATH=${giTypelibPath}"
        "XDG_DATA_DIRS=${xdgDataDirs}"
        "GSETTINGS_SCHEMA_DIR=${notifdSchemaDir}"
      ];
      ExecStart = "${lib.getExe pkgs.ags} run %h/.config/ags/app.ts";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.astal-notifd = {
    Unit = {
      Description = "Astal notification daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Environment = [
        "GI_TYPELIB_PATH=${giTypelibPath}"
        "XDG_DATA_DIRS=${xdgDataDirs}"
        "GSETTINGS_SCHEMA_DIR=${notifdSchemaDir}"
      ];
      ExecStart = notifdExe;
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
