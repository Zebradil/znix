_: {
  znix.workarounds.yt6801 = {
    package = "linuxKernel.packages.linux_xanmod_latest.yt6801";
    systems = [ "x86_64-linux" ];
    reason = "yt6801 builds without kernelModuleMakeFlags, so its output carries its own depmod index (modules.*) that collides with the kernel's in the module tree; fixed upstream by NixOS/nixpkgs#577453.";
    override = pkgs: old: {
      makeFlags = pkgs.linuxKernel.packages.linux_xanmod_latest.kernelModuleMakeFlags ++ old.makeFlags;
    };
  };
}
