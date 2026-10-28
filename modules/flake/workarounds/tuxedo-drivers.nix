_: {
  znix.workarounds.tuxedo-drivers = {
    package = "linuxKernel.packages.linux_xanmod_latest.tuxedo-drivers";
    systems = [ "x86_64-linux" ];
    reason = "tuxedo-drivers' Makefile re-passes $(MAKEFLAGS) through the shell unquoted, which breaks on the kernel's `cmd_sign=...$(space)$@` make flag.";
    # The inner make inherits MAKEFLAGS from the environment anyway, so the
    # explicit copy is redundant, and dropping it keeps kmodigest signing.
    override = _pkgs: old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace Makefile --replace-fail ' $(MAKEFLAGS)' ""
      '';
    };
  };
}
