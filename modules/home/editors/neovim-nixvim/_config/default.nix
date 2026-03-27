{
  pkgs,
  inputs,
  lib,
}:
let
  entries = builtins.readDir ./.;
  nixFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
  ) entries;
  configs = lib.mapAttrsToList (name: _: import (./. + "/${name}") { inherit pkgs inputs; }) nixFiles;
in
lib.foldl' lib.recursiveUpdate { } configs
