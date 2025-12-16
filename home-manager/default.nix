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
    ./modules/neovim.nix
    ./modules/starship.nix
    ./modules/zoxide.nix
    ./modules/zsh.nix
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

  home.packages = with pkgs; [
    # Desktop apps
    alacritty
    keepassxc
    #slack
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
    gke-kubeconfiger
    gnumake
    gnused
    go-task
    goreleaser
    home-manager
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
    sops
    stern
    terraform
    velero
    vendir
    watchexec
    wget
    yq-go
    ytt

    # languages
    go
    gofumpt

    nil
    nixd
    nixfmt

    python3

    rustup

    uv

    # shell
    zsh-completions
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

  # The state version is required and should stay at the version you originally installed.
  home.stateVersion = "24.05";
}
