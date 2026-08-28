{ inputs, ... }:
{
  # Not `follows`-ing nixpkgs: blebridge builds a static-musl aarch64 binary
  # through crane + pkgsCross with hand-tuned RUSTFLAGS (see its flake.nix).
  # Repointing that at znix's nixpkgs risks breaking the cross toolchain for no
  # runtime gain -- the result is a single statically linked file either way.
  flake-file.inputs.blebridge.url = "github:Zebradil/blebridge";

  # blebridge: bridges the BLE FTMS treadmill to ANT+ watches and mobile apps.
  # Host-scoped (single consumer), same as toddler-adguard. Closes DEFER-5 in
  # docs/hosts/toddler.md.
  #
  # Deployed as a native systemd unit rather than the container the upstream
  # repo ships. blebridge's ADR 0001 keeps Docker so *other users* can run it;
  # it never required the owner's own host to. A docker daemon on a 957 MB Pi
  # that already serves LAN DNS is rent we decline to pay.
  flake.modules.nixos.toddler-blebridge = {
    systemd.services.blebridge = {
      description = "BLE FTMS treadmill bridge (ANT+ broadcaster + BLE app endpoint)";
      # An occasional crash should self-heal; a crash *loop* must not. Every
      # start touches the BT500, and its USB resets take Ethernet down with
      # them (see DEFER-9), so a bridge that cannot stay up is worth less than
      # LAN DNS. More than 5 starts in an hour and systemd parks the unit in
      # `failed` for good -- recover with `systemctl reset-failed blebridge`.
      # The window is an hour, not the default 10s, so a slow loop (a crash
      # every few minutes) trips it too instead of resetting USB forever.
      unitConfig = {
        StartLimitIntervalSec = "1h";
        StartLimitBurst = 5;
      };
      wantedBy = [ "multi-user.target" ];
      # BlueZ owns org.bluez on the system bus; both BLE roles are D-Bus clients.
      after = [
        "bluetooth.service"
        "dbus.service"
      ];
      requires = [ "bluetooth.service" ];

      environment = {
        # The App Endpoint has to advertise from the onboard Broadcom radio.
        # The ASUS BT500's RTL8761BU never sends LE Enhanced Connection
        # Complete for connections to its own extended advertisement, so the
        # kernel drops every ACL from the phone and GATT is dead air. On this
        # board it is worse than useless: left to auto-assign with both radios
        # present, blebridge put the App Endpoint on hci1 and the link threw
        # "hci1: Unexpected advertising set terminated event" followed by a
        # dwc2 USB reset. A 3B+ carries its Ethernet on that same USB bus, so
        # the box dropped off the LAN and wedged seconds into every boot.
        #
        # Only the App side is pinned: the Link then takes whatever is left
        # (`not_app` in blebridge's assign_adapters), so the dongle may
        # renumber freely while hci0, the UART chip, never does.
        BLEBRIDGE_APP_ADAPTER = "hci0";
        RUST_LOG = "info";
      };

      serviceConfig = {
        # x86_64-linux attribute holding an aarch64 binary: it is a static-musl
        # cross build, so the deployer (tuxedo, x86_64) produces it natively
        # with no emulation. That is what lets ADR 0001's "toddler is never
        # built on-box" hold for a Rust program.
        ExecStart = "${inputs.blebridge.packages.x86_64-linux.blebridge-arm64}/bin/blebridge";

        # ponytail: runs as root, as the container did. The BlueZ D-Bus policy
        # grants send_interface for GattCharacteristic1/GattDescriptor1/
        # LEAdvertisement1 to user="root" only, so an unprivileged unit needs a
        # bespoke org.bluez policy drop-in. Add one (plus the `dialout` group
        # for raw ANT+ USB, whose udev rules already exist) if this ever grows
        # beyond a single-purpose appliance.
        #
        # No CapabilityBoundingSet yet: the container ran with docker's default
        # set plus NET_ADMIN, and guessing the minimum here trades a working
        # deploy for a silent startup failure on a headless box. Tighten toward
        # CAP_NET_ADMIN once the service is proven up.
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;

        # Crash-only, per blebridge's ADR 0001: subsystems retry transient
        # errors themselves and anything unexpected exits the process. So a
        # non-zero exit is worth retrying: a boot race (hci0 not yet up, ANT+
        # stick not yet enumerated) clears on the next attempt. The rate limit
        # above is what stops that from becoming a loop.
        Restart = "on-failure";
        RestartSec = 30;

        # ponytail: mirrors the container's `mem_limit: 64m`. The cap exists to
        # protect AdGuard -- an OOM on this 889 MB box must not take LAN DNS
        # with it. Raise it if the bridge starts getting killed under load.
        MemoryMax = "64M";
      };
    };
  };
}
