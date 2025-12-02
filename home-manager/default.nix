{
  nix-index-database,
  pkgs,
  user,
}:
let
  xdgHome = if pkgs.stdenv.isDarwin then "/Users/${user}" else "/home/${user}";
in
{
  imports = [
    nix-index-database.homeModules.nix-index
    ./modules/google-cloud-sdk.nix
    ./modules/neovim
    ./modules/starship.nix
    ./modules/zoxide.nix
    ./modules/zsh.nix
    ./modules/wezterm
  ];

  home.username = user;
  home.homeDirectory = xdgHome;

  xdg = {
    enable = true;
    cacheHome = "${xdgHome}/.cache";
    configHome = "${xdgHome}/.config";
    dataHome = "${xdgHome}/.local/share";
    stateHome = "${xdgHome}/.local/state";
  };

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # Desktop apps
    alacritty
    antigravity-fhs
    keepassxc
    kitty
    slack
    telegram-desktop
    vscode-fhs
    # Buggy, replaced by Edge PWA
    #youtube-music
    #zoom-us

    # Desktop-CLI integrations
    tridactyl-native

    # CLI apps
    bat
    btop
    delta
    htop
    jnv
    k9s
    lazygit
    tailscale
    tmux
    translate-shell

    # CLI tools
    _1password-cli
    bashInteractive
    coreutils
    curl
    direnv
    dive
    duf
    eza
    fd
    formatjson5
    fzf
    gh
    ghorg
    git
    # gke-kubeconfiger
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
    nmap
    ncdu
    rage
    rancher
    repgrep
    ripgrep
    rsync
    skopeo
    stern
    terraform
    velero
    vendir
    watchexec
    wget
    yq-go
    ytt

    # Fonts
    nerd-fonts.iosevka

    # languages
    go
    gofumpt

    python3

    rustup

    uv

    # shell
    zsh-completions

    # Wayland
    wl-clipboard
  ];

  services.syncthing.enable = true;

  home.file = {
    "${xdgHome}/.local/bin" = {
      source = ./bin;
      recursive = true;
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.fzf.enable = true;
  programs.nix-index.enable = true;

  fonts = {
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "Iosevka NFM" ];
      };
    };
  };

  # The state version is required and should stay at the version you originally installed.
  home.stateVersion = "24.05";
}
