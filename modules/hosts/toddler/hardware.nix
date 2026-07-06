{ inputs, ... }:
{
  flake.modules.nixos.toddler-hardware =
    { modulesPath, pkgs, ... }:
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
      # boot.kernelPackages = pkgs.linuxPackages;

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
