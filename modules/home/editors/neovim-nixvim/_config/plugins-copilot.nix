_: {
  # ─ Copilot ────────────────────────────────────────────────────
  # copilot-language-server wired as a plain LSP client. `activate = false`
  # skips the vim.lsp.enable() call, so no process spawns until <Leader>ct
  # flips it; that toggle also stops the client on the way back down.
  # nvim-lspconfig's copilot config defaults telemetryLevel to "all".
  lsp.servers.copilot = {
    enable = true;
    activate = false;
    config.settings = {
      telemetry.telemetryLevel = "off";
      # The server defaults this map to
      # {"*": true, plaintext: false, markdown: false, scminput: false},
      # which silences both completions and NES in prose buffers.
      github.copilot.enable = {
        "*" = true;
        markdown = true;
        plaintext = true;
      };
    };
  };

  # Next edit suggestions over the copilot client. sidekick never starts a
  # server itself — with no client attached it issues no requests, so the
  # vim.lsp.enable state above is the only gate.
  plugins.sidekick.enable = true;
}
