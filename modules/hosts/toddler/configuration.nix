{ inputs, ... }:
{
  # toddler: Raspberry Pi 3B+ LAN appliance (aarch64). Headless.
  # See docs/hosts/toddler.md and docs/adr/0001-toddler-appliance-host.md.
  flake.modules.nixos.toddler =
    { pkgs, ... }:
    {
      imports = with inputs.self.modules.nixos; [
        nix-settings # kasha binary cache substituter — avoids emulated rebuilds
        openssh # SSH + sudo via ssh-agent (no password secret)
        suok # lean admin user
        toddler-hardware
        toddler-adguard
      ];

      networking = {
        hostName = "toddler";
        # Wired eth0, DHCP; IP pinned to 192.168.0.20 by a router reservation for
        # MAC b8:27:eb:87:9a:96. WiFi intentionally unused.
        interfaces.eth0.useDHCP = true;
        # ponytail: the host resolves via a public upstream, not itself or the
        # router, to avoid a circular dependency when AdGuard is down or rebuilding.
        nameservers = [ "9.9.9.9" ];
      };

      system.stateVersion = "25.11";

      # No ZFS on this appliance; adopt the 26.11 default explicitly to silence the
      # forceImportRoot deprecation warning (the zfs module is pulled in by the
      # sd-image profile even though no zfs pool is used).
      boot.zfs.forceImportRoot = false;

      # AdGuard owns :53, so systemd-resolved's stub listener must not.
      services.resolved.enable = false;

      # Minimal locale/timezone. Deliberately NOT the shared `locale` module: it
      # pulls geoclue2 + automatic-timezoned (network location service), unwanted
      # on a headless appliance.
      time.timeZone = "Europe/Berlin";
      i18n.defaultLocale = "en_US.UTF-8";

      environment.systemPackages = with pkgs; [
        htop
        btop
        ncdu
        iotop-c
      ];
    };
}
