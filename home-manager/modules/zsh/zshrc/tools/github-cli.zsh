# +==========================+
# | GitHub CLI related       |
# +--------------------------+

if lib::check_commands gh; then
  my:gh:cd-to-repo() {
    local repo="${1:?repo name is required}"
    # Check if $repo contains a slash, if not, add the default org
    if [[ ! "$repo" =~ / ]]; then
      repo="zebradil/$repo"
    fi
    local dir="$HOME/code/github.com/$repo"
    if [[ ! -d "$dir" ]]; then
      gh repo clone "$repo" "$dir"
      cd "$dir"
    else
      cd "$dir"
      git fetch --all --prune
    fi
  }

  alias ghcd=my:gh:cd-to-repo
fi
