{ ... }:
{
  flake.modules.homeManager.cli-tools =
    { pkgs, lib, ... }:
    {
      home.packages = with pkgs; [
        # Desktop apps
        alacritty
        keepassxc

        # Desktop-CLI integrations
        tridactyl-native

        # CLI apps
        bat
        broot
        btop
        delta
        difftastic
        htop
        jnv
        k9s
        lazygit
        nh
        tailscale
        tmux
        translate-shell

        # CLI tools
        bashInteractive
        coreutils
        curl
        dive
        duf
        eza
        fd
        formatjson5
        gh
        ghorg
        git
        gnumake
        gnused
        go-task
        goreleaser
        inetutils
        ipcalc
        jq
        just
        krew
        kubectl
        kubernetes-helm
        mise
        moreutils
        myks
        ncdu
        nmap
        nodejs
        rage
        rancher
        repgrep
        ripgrep
        rsync
        sd
        skopeo
        sops
        stern
        terraform
        vals
        velero
        vendir
        watchexec
        wget
        yq-go
        ytt

        # Languages
        go
        go-tools
        gofumpt
        golangci-lint
        gopls

        nil
        nixd
        nixfmt

        python3

        rustup

        uv

        # Shell
        zsh-completions
      ];
    };
}
