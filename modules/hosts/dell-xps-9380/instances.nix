{ inputs, lib, ... }:
let
  system = "x86_64-linux";

  hosts = {
    d1.address = "192.168.0.111/24";
    d2.address = "192.168.0.112/24";
    d3.address = "192.168.0.113/24";
  };
in
{
  flake = {
    modules.nixos = lib.mapAttrs (name: h: {
      imports = [ inputs.self.modules.nixos.dell-xps-9380 ];
      networking.hostName = name;
      znix.wirelessHeadless.address = h.address;
    }) hosts;

    nixosConfigurations = lib.mergeAttrsList (
      lib.mapAttrsToList (name: _: inputs.self.lib.mkNixos system name { }) hosts
    );

    nixosSystemMap = lib.genAttrs (builtins.attrNames hosts) (_: system);
  };
}
