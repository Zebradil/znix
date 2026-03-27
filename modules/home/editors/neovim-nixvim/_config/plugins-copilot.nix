_: {
  plugins = {

    # ─ Copilot ────────────────────────────────────────────────────
    copilot-lua = {
      enable = true;
      settings = {
        suggestion = {
          enabled = true;
          auto_trigger = false;
          keymap = {
            accept = "<M-l>";
            accept_word = false;
            accept_line = false;
            next = "<M-]>";
            prev = "<M-[>";
            dismiss = "<C-]>";
          };
        };
        panel.enabled = false;
        filetypes = {
          yaml = true;
          markdown = true;
          gitcommit = true;
          "*" = true;
        };
      };
    };
  };
}
