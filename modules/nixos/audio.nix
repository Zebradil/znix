_: {
  flake.modules.nixos.audio = _: {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;

      # Constrain the Samson G-Track Pro (USB 17a0:0241) to USB Audio
      # altsetting 1 only. Its altsetting 2 (88.2/96 kHz, 388 bytes per
      # microframe) exceeds the xHCI scheduler bandwidth budget on the
      # WD19TB dock — the kernel rejects every set_alt(2) with
      # "Not enough bandwidth for altsetting 2", and ACP profile
      # negotiation then fails entirely, leaving the card with zero
      # usable Sources/Sinks.
      #
      # Disabling ACP for this device skips that profile dance — raw
      # per-direction nodes appear directly. Pinning allowed-rates to
      # the alt-1 set (32/44.1/48 kHz) keeps every stream within
      # alt-1's bandwidth, so the kernel never requests alt 2.
      wireplumber.extraConfig."51-samson-g-track-pro" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              {
                "device.vendor.id" = "0x17a0";
                "device.product.id" = "0x0241";
              }
            ];
            actions.update-props = {
              "api.alsa.use-acp" = false;
            };
          }
          {
            matches = [
              { "node.name" = "~alsa_(input|output)\\..*Samson.*G-Track.*"; }
            ];
            actions.update-props = {
              "audio.rate" = 48000;
              "audio.allowed-rates" = [
                32000
                44100
                48000
              ];
              # With ACP disabled, pipewire's spa-alsa otherwise probes the
              # raw device with its default audio.channels = 64 and the
              # Samson (stereo: 2 channels in, 2 channels out) rejects it
              # with "Channels doesn't match (requested 64, got 2)". Pin
              # channel layout explicitly.
              "audio.channels" = 2;
              "audio.position" = "[ FL FR ]";
            };
          }
        ];
      };
    };
  };
}
