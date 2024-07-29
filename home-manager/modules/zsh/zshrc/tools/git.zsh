function z::git:current_branch() {
  local ref
  ref=$(git symbolic-ref --quiet HEAD 2> /dev/null)
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # no git repo.
    ref=$(git rev-parse --short HEAD 2> /dev/null) || return
  fi
  echo ${ref#refs/heads/}
}


function z::git:repo_name() {
  local repo_path
  if repo_path="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$repo_path" ]]; then
    echo ${repo_path:t}
  fi
}

function z::git:main_branch() {
  command git rev-parse --git-dir &>/dev/null || return
  local ref
  for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,stable,master}; do
    if command git show-ref -q --verify $ref; then
      echo ${ref:t}
      return 0
    fi
  done

  echo master
  return 1
}

function z::git:rename() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: $0 old_branch new_branch"
    return 1
  fi

  git branch -m "$1" "$2"
  if git push origin --delete "$1"; then
    git push --set-upstream origin "$2"
  fi
}

alias grt='cd "$(git rev-parse --show-toplevel || echo .)"'

alias g='git'
alias ga='git add'
alias gb='git branch'

alias gbg='LANG=C git branch -vv | grep ": gone\]"'
alias gbgd='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '"'"'{print $1}'"'"' | xargs git branch -d'
alias gbgD='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '"'"'{print $1}'"'"' | xargs git branch -D'

alias gco='git checkout'
alias gcm='git checkout $(z::git:main_branch)'

alias gc='git commit --verbose'
alias gc!='git commit --verbose --amend'
alias gd='git diff'
alias gdca='git diff --cached'

alias gf='git fetch'

alias glo='git log --oneline --decorate'
alias glol='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'

alias gl='git pull'
alias gp='git push'

alias gpsup='git push --set-upstream origin $(z::git:current_branch)'
alias gpoat='git push origin --all && git push origin --tags'
alias gpod='git push origin --delete'

alias grhh='git reset --hard'
alias grst='git restore --staged'
alias gst='git status'
alias gwt='git worktree'
