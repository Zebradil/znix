_: {
  znix.workarounds.claude-code-darwin-ca = {
    package = "claude-code";
    systems = [ "aarch64-darwin" ];
    reason = "claude-code forces CLAUDE_CODE_CERT_STORE=system, which on Darwin reads the keychain without Apple's built-in roots, so every API call fails TLS (NixOS/nixpkgs#579204); fixed upstream by NixOS/nixpkgs#579756.";
    # Prepended so the package's own wrapProgram stays the binary one; this only
    # needs wrapProgramShell for --run. Reading NIX_SSL_CERT_FILE at runtime keeps
    # the host's cacert, security.pki blacklist included.
    override = pkgs: old: {
      nativeBuildInputs = [ pkgs.makeShellWrapper ] ++ old.nativeBuildInputs;
      postInstall = (old.postInstall or "") + ''
        wrapProgramShell $out/bin/claude --run ${pkgs.lib.escapeShellArg ''
          if [ -z "''${NODE_EXTRA_CA_CERTS:-}" ] && [ -n "''${NIX_SSL_CERT_FILE:-}" ]; then
            export NODE_EXTRA_CA_CERTS="$NIX_SSL_CERT_FILE"
          fi
        ''}
      '';
    };
    # Runtime breakage, so a build proves nothing. Passes once the wrapper either
    # stops forcing the system store or feeds NODE_EXTRA_CA_CERTS, as upstream's
    # fix does.
    check =
      pkgs: package:
      pkgs.runCommand "claude-code-darwin-ca-check" { } ''
        wrapper=${package}/bin/claude
        if grep -aq CLAUDE_CODE_CERT_STORE "$wrapper" && ! grep -aq NODE_EXTRA_CA_CERTS "$wrapper"; then
          echo "$wrapper forces CLAUDE_CODE_CERT_STORE without NODE_EXTRA_CA_CERTS; workaround still needed" >&2
          exit 1
        fi
        touch $out
      '';
  };
}
