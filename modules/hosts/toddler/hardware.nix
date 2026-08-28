{ inputs, ... }:
{
  flake.modules.nixos.toddler-hardware =
    {
      config,
      lib,
      modulesPath,
      pkgs,
      ...
    }:
    {
      imports = [
        inputs.hardware.nixosModules.raspberry-pi-3
        # Build a bootable RPi 3B+ SD image FROM this exact config, so a reflash
        # yields a card that boots straight into the final system (suok + SSH
        # key + AdGuard) with no console/keyboard bootstrap. Owns the boot
        # loader (extlinux + firmware partition) and the `/` + `/boot/firmware`
        # fileSystems by label — do NOT redefine them here or eval conflicts.
        # Build: nix build .#nixosConfigurations.toddler.config.system.build.sdImage
        (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
      ];

      # Mainline kernel instead of the nixos-hardware downstream RPi kernel:
      # that one is not on Hydra, so it triggers an hours-long emulated kernel
      # compile. Mainline supports the 3B+ (incl. UART Bluetooth) and is cached.
      #
      # Not optional: the sd-image-aarch64 profile above populates the firmware
      # partition (VideoCore blobs + DTBs) for the *mainline* kernel, while
      # nixos-hardware's `raspberry-pi-3` mkDefaults the downstream `linux-rpi`.
      # That pairing left both Bluetooth radios dead on the box -- the mini-UART
      # never got pin maps ("bcm2835-aux-uart 3f215040.serial: there is not
      # valid maps for state default") and hci0 timed out on its first vendor
      # command (0xfc18, "BCM: Reset failed (-110)").
      boot.kernelPackages = pkgs.linuxPackages;

      # On a 3B+ the PL011 (ttyAMA0, 3f201000.serial) IS the onboard Bluetooth
      # HCI UART -- the header console is the mini-UART (ttyS0, GPIO14/15). The
      # sd-image profile hardcodes `console=ttyAMA0,115200n8` for QEMU's
      # `-machine virt`, which puts a kernel console on the BT chip's line:
      # printk output goes out its RX pin, pl011_console_write() clears
      # CR_CTSEN for every write (dropping hardware flow control on a link
      # declared `uart-has-rtscts`), and uart_port_startup() overrides serdev's
      # requested termios with the console's on first open. hci0 dies on its
      # first vendor command (0xfc18, "BCM: Reset failed (-110)"). Raspbian
      # used `console=serial0` -> ttyS0 and never had this.
      #
      # boot.kernelParams is a plain list and neither the sd-image profile nor
      # nixos-hardware's raspberry-pi/3 uses mkDefault, so mkForce over the
      # whole list is the only way to drop one entry. root=fstab comes from
      # nixpkgs' systemd-initrd module and is boot-critical -- keep it.
      boot.kernelParams = lib.mkForce [
        "console=ttyS0,115200n8"
        "console=tty0"
        "nohibernate"
        "root=fstab"
        "loglevel=${toString config.boot.consoleLogLevel}"
        "lsm=${lib.concatStringsSep "," config.security.lsm}"
      ];

      # Mainline names this board's DTB after the SoC (bcm2837); the downstream
      # rpi kernel calls the same file bcm2710-*. U-Boot resolves FDTDIR using
      # `$fdtfile` from the VideoCore firmware, which says bcm2710-rpi-3-b-plus
      # .dtb -- absent from a mainline dtbs tree. The entry then fails and
      # extlinux silently boots the *previous* generation, so a deploy looks
      # like it applied while `uname -r` still reports the old kernel. Naming
      # the DTB makes the generator emit a concrete `FDT` line instead.
      hardware.deviceTree.name = "broadcom/bcm2837-rpi-3-b-plus.dtb";

      hardware.enableRedistributableFirmware = true;

      # blebridge substrate. The app itself is deployed later (DEFER-5); the OS
      # only guarantees BLE + ANT+ access here.
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
        # BLE central features blebridge relies on need the experimental API.
        settings.General.Experimental = true;
      };
      environment.systemPackages = [ pkgs.usbutils ];

      # ANT+ USB sticks are libusb userspace devices (no kernel driver). Grant
      # non-root raw access so the blebridge service user can open them.
      # 0fcf:1008 = ANTUSB2, 0fcf:1009 = ANTUSB-m.
      services.udev.extraRules = ''
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0fcf", ATTRS{idProduct}=="1008", MODE="0660", GROUP="dialout", TAG+="uaccess"
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0fcf", ATTRS{idProduct}=="1009", MODE="0660", GROUP="dialout", TAG+="uaccess"
      '';
    };
}
