{ ... }:
{
  flake-file.inputs.nixpkgs-pin-mise.url = "github:NixOS/nixpkgs/9bc02893134c733dd85de46ee4fb2fac696b5529";

  znix.workarounds.mise = {
    pin = "nixpkgs-pin-mise";
    reason = "mise fails to build in later nixpkgs revisions: missing cmake.";
  };
}
