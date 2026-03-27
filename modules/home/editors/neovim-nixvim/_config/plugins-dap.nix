_: {
  plugins = {

    # ─ DAP ────────────────────────────────────────────────────────
    dap.enable = true;
    dap-go.enable = true;
    dap-ui.enable = true;

    # ─ Testing ────────────────────────────────────────────────────
    neotest = {
      enable = true;
      adapters = {
        golang = {
          enable = true;
          settings = {
            go_test_args = [
              "-v"
              "-race"
              "-timeout=60s"
            ];
            dap_go_enabled = true;
          };
        };
      };
      settings = {
        output.open_on_run = false;
        quickfix.open = false;
      };
    };
  };
}
