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

# Directory of the main working tree, also when called from inside a worktree.
function z::git:wt_root() {
  local common
  common=$(git rev-parse --path-format=absolute --git-common-dir) || return
  print -r -- "${common:h}"
}

# Worktree directory for a branch. Slashes are flattened so that removing a
# worktree never leaves empty parent directories behind.
function z::git:wt_dir() {
  local root
  root=$(z::git:wt_root) || return
  print -r -- "$root/.worktrees/${1//\//-}"
}

# Path of the worktree that has the branch checked out, empty if there is none.
function z::git:wt_find() {
  git worktree list --porcelain |
    awk -v b="branch refs/heads/$1" '/^worktree /{p=substr($0,10)} $0==b{print p; exit}'
}

# True if the branch tip is contained in any ref other than the branch itself
# and its remote counterparts.
function z::git:wt_merged_ref() {
  setopt localoptions extendedglob
  local sha
  sha=$(git rev-parse --verify -q "refs/heads/$1") || return 1
  local refs=(${(f)"$(git for-each-ref --contains "$sha" --format='%(refname)' refs/heads refs/remotes)"})
  refs=(${refs:#refs/heads/$1})
  # [^/]## so that a remote branch named <remote>/<other>/$1 still counts.
  refs=(${refs:#refs/remotes/[^/]##/$1})
  (( $#refs ))
}

# True if GitHub reports a merged pull request for the branch. This is the only
# reliable way to recognise a squash merge: the squashed commit shares no sha
# and no parent with the branch.
function z::git:wt_merged_pr() {
  lib::check_commands gh || return 1
  [[ $(gh pr view "$1" --json state --jq .state 2>/dev/null) == MERGED ]]
}

# Lowercase slug: runs of anything but letters and digits collapse into one dash.
function z::git:wt_slug() {
  setopt localoptions extendedglob
  local s=${${1:l}//[^a-z0-9]##/-}
  print -r -- "${${s#-}%-}"
}

# wtn [branch-or-description] [base]: create or check out a worktree under
# .worktrees and cd into it. An existing local or remote branch is used as is,
# anything else becomes a new wt/<date>-<time>-<slug> branch, so "wtn 'fix flaky
# check'" lands on wt/260919-2257-fix-flaky-check. To choose a new branch name
# verbatim, create the branch first and pass it by name. base applies to new
# branches only; an existing branch is checked out where it already points.
function wtn() {
  local branch=$1
  local dir new=

  if git show-ref -q --verify "refs/heads/$branch"; then
    dir=$(z::git:wt_find "$branch")
    if [[ -n $dir ]]; then
      log::info "$branch is already checked out"
      cd "$dir"
      return
    fi
    log::info "checking out existing local branch $branch"
  elif [[ -n $branch && -n $(git for-each-ref --format=x "refs/remotes/*/$branch") ]]; then
    log::info "creating $branch to track the remote branch of the same name"
  else
    local slug
    slug=$(z::git:wt_slug "$branch")
    branch=wt/$(date +%y%m%d-%H%M%S)${slug:+-$slug}
    log::info "creating new branch $branch from ${2:-HEAD}"
    new=1
  fi

  dir=$(z::git:wt_dir "$branch") || return
  if [[ -n $new ]]; then
    git worktree add -b "$branch" "$dir" "${2:-HEAD}"
  else
    git worktree add "$dir" "$branch"
  fi && cd "$dir"
}

# wtg [query]: pick a worktree with fzf and cd into it.
function wtg() {
  lib::check_commands fzf || return 1
  local dir
  dir=$(git worktree list --porcelain | sed -n 's/^worktree //p' |
    fzf --query="$1" --select-1 --exit-0) && cd "$dir"
}

# wtrm [-f|--force] [branch]: remove a worktree, the current one by default, and
# its branches: the one checked out in it and the one its directory is named
# after, which differ once another branch was checked out inside the worktree.
# The main branch is never deleted. Refuses uncommitted changes and branches
# whose work exists nowhere else.
function wtrm() {
  local force=()
  [[ $1 == (-f|--force) ]] && { force=(--force); shift }

  local root dir
  root=$(z::git:wt_root) || return
  if [[ -n $1 ]]; then
    dir=$(z::git:wt_find "$1")
    if [[ -z $dir ]]; then
      log::error "no worktree for $1"
      return 1
    fi
  else
    dir=$(git rev-parse --show-toplevel) || return
  fi
  if [[ ${dir:A} == ${root:A} ]]; then
    log::error "refusing to remove the main worktree"
    return 1
  fi

  local b branches=($(git -C "$dir" symbolic-ref -q --short HEAD))
  for b in ${(f)"$(git for-each-ref --format='%(refname:lstrip=2)' refs/heads)"}; do
    [[ ${b//\//-} == ${dir:t} ]] && branches+=($b)
  done
  branches=(${(u)branches:#$(z::git:main_branch)})

  if (( ! $#force )); then
    if [[ -n $(git -C "$dir" status --porcelain) ]]; then
      log::error "${dir:t} has uncommitted changes or untracked files, use --force"
      return 1
    fi
    for b in $branches; do
      if z::git:wt_merged_ref "$b"; then
        log::info "$b is merged into another ref"
      elif z::git:wt_merged_pr "$b"; then
        log::info "$b is merged through a pull request"
      else
        log::error "$b is not merged anywhere, use --force"
        return 1
      fi
    done
  fi

  # :A on both sides: $PWD is logical, git reports resolved paths, and missing the
  # match would delete the shell's own cwd.
  [[ ${PWD:A}/ == ${dir:A}/* ]] && cd "$root"
  git worktree remove $force "$dir" || return
  # -D, not -d: a squash-merged branch is never "fully merged" to git.
  (( ! $#branches )) || git branch -D $branches
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
