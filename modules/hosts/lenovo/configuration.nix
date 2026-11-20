{ inputs, ... }:
{
  # lenovo — ThinkPad T480s, a family laptop for video calls and browsing.
  # One desktop user (alis) on GNOME; administered over SSH as suok.
  flake.modules.nixos.lenovo =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports =
        (with inputs.self.modules.nixos; [
          audio
          boot
          gnome
          laptop
          lenovo-disko
          lenovo-hardware
          locale
          nix-settings
          openssh
          pki
          sops
          suok
          wireless
        ])
        ++ [ inputs.disko.nixosModules.disko ];

      networking.hostName = "lenovo";
      system.stateVersion = "26.11";

      znix = {
        boot.enable = true;
        laptop.enable = true;
        wireless.enable = true;
      };

      zramSwap.enable = true;
      # BIOS, NVMe and Thunderbolt firmware come from LVFS.
      services.fwupd.enable = true;

      # A home laptop: a fixed zone beats GeoClue lookups, which time out here
      # and leave the clock on UTC. locale's default Europe/Berlin applies.
      services.automatic-timezoned.enable = lib.mkForce false;

      i18n.extraLocales = [ "ru_RU.UTF-8/UTF-8" ];
      services.xserver.xkb.layout = "us,ru";

      # Her login and UI language carry over from the previous install.
      sops.secrets.alis-password = {
        sopsFile = ../../../secrets/hosts/lenovo.yaml;
        neededForUsers = true;
      };
      users.users.alis = {
        isNormalUser = true;
        description = "Alis";
        hashedPasswordFile = config.sops.secrets.alis-password.path;
        extraGroups = [ "networkmanager" ];
      };
      # `f` writes only when the file is missing, so a language she picks
      # later in Settings sticks.
      systemd.tmpfiles.rules = [
        ''f /var/lib/AccountsService/users/alis 0600 root root - [User]\nLanguages=ru_RU.UTF-8;\n''
      ];

      services.printing = {
        enable = true;
        drivers = [ pkgs.brlaser ];
      };
      # Driverless printer discovery, and lenovo.local for colmena: the
      # router names only one of the laptop's DHCP leases.
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        settings.publish = {
          disable-publishing = false;
          publish-addresses = true;
        };
      };
      hardware.printers.ensurePrinters = [
        {
          name = "Brother-DCP-L2530DW";
          location = "Home";
          deviceUri = "socket://192.168.1.35:9100";
          # shortcut: brlaser has no DCP-L2530DW entry; the L2537DW is its
          # regional twin. Switch to IPP Everywhere if prints come out wrong.
          model = "drv:///brlaser.drv/brl2537d.ppd";
          ppdOptions.PageSize = "A4";
        }
      ];
      hardware.printers.ensureDefaultPrinter = "Brother-DCP-L2530DW";

      programs = {
        firefox.enable = true;
        zoom-us.enable = true;
      };
      environment.systemPackages = with pkgs; [
        google-chrome
        hunspellDicts.de_DE
        hunspellDicts.en_US
        hunspellDicts.ru_RU
        libreoffice
        telegram-desktop
      ];
    };
}
