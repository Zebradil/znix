{ inputs, lib, ... }:
let
  system = "x86_64-linux";

  # /16, not /24: the router's LAN is 192.168.0.1/16 and its DHCP pool starts at
  # offset 256, so laptops land on 192.168.1.x. A /24 here makes those clients
  # off-subnet, and every reply hairpins through the router's CPU (~280 Mbit,
  # with retransmits) instead of being switched.
  hosts = {
    d1 = {
      address = "192.168.0.111/16";
      fallback = "192.168.0.121/16";
      vpn = "100.104.120.72";
      adguard = true;
    };
    d2 = {
      address = "192.168.0.112/16";
      fallback = "192.168.0.122/16";
      vpn = "100.90.127.59";
    };
    d3 = {
      address = "192.168.0.113/16";
      fallback = "192.168.0.123/16";
      vpn = "100.122.248.98";
    };
  };
in
{
  flake = {
    modules.nixos = lib.mapAttrs (name: h: {
      imports = [ inputs.self.modules.nixos.dell-xps-9380 ];
      networking.hostName = name;
      znix.adguard.enable = h.adguard or false;
      znix.dualNet = {
        address = h.address;
        fallbackAddress = h.fallback;
      };
      znix.k3sNode = {
        selfLan = lib.head (lib.splitString "/" h.address);
        selfVpn = h.vpn;
      };
    }) hosts;

    nixosConfigurations = lib.mergeAttrsList (
      lib.mapAttrsToList (name: _: inputs.self.lib.mkNixos system name { }) hosts
    );

    nixosSystemMap = lib.genAttrs (builtins.attrNames hosts) (_: system);
  };
}
