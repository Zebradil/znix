{ ... }:
{
  znix.workarounds.mise-cmake = {
    package = "mise";
    systems = [ "aarch64-darwin" ];
    reason = "nixpkgs keeps cmake in mise's nativeCheckInputs, so mise-darwin-tests drops it and libz-ng-sys's build script cannot find it.";
    override = pkgs: old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.cmake ];
    };
  };
}
