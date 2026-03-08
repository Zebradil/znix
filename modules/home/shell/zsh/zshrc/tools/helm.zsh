# +==========================+
# | Helm configuration       |
# +--------------------------+

if lib::check_commands helm yq; then
  log::debug "Configuring Helm"

  function z:helm:list-chart-dependencies() (
    set -euo pipefail

    local chart_path="${1:-.}"

    if [[ ! -f "$chart_path/Chart.yaml" ]]; then
      log::error "Chart.yaml not found in $chart_path"
      return 1
    fi

    # Get current helm repositories
    local -A repo_map
    while IFS=$'\t' read -r repo_name repo_url; do
      # Clean up the URL by removing trailing slashes and common suffixes
      local clean_url="$repo_url"
      clean_url="${clean_url%/}"
      clean_url="${clean_url%/index.yaml}"
      repo_map["$clean_url"]="$repo_name"
    done < <(helm repo list -o json 2>/dev/null | jq -r '.[] | [.name, .url] | @tsv' || true)

    while read -r name version repository; do
      log::info "Processing $name from $repository"

      # Clean up the repository URL to match our mapping
      local clean_repo="$repository"
      clean_repo="${clean_repo%/}"
      clean_repo="${clean_repo%/index.yaml}"

      # Find the local repository name for this URL
      local repo_name=""
      if [[ -n "${repo_map[$clean_repo]:-}" ]]; then
        repo_name="${repo_map[$clean_repo]}"
      else
        # Try to find a partial match if exact match fails
        for repo_url in "${!repo_map[@]}"; do
          if [[ "$clean_repo" == *"$repo_url"* ]] || [[ "$repo_url" == *"$clean_repo"* ]]; then
            repo_name="${repo_map[$repo_url]}"
            break
          fi
        done

        if [[ -z "$repo_name" ]]; then
          log::warn "Repository $repository not found in helm repos. Please add it with: helm repo add <name> $repository"
          continue
        fi
      fi

      local chart="$repo_name/$name"
      local latest_version=""
      latest_version=$(helm search repo "$chart" -oyaml 2>/dev/null | yq ".[] | select(.name == \"$chart\").version" || true)

      if [[ -z "$latest_version" ]]; then
        log::error "Chart $chart not found in repository $repo_name."
        continue
      fi

      # Format output with highlighting for name
      echo -n "$(log::highlight "$name") "
      if [[ "$version" != "$latest_version" ]]; then
        echo -n "${LOGGER_COLOR_RED}$version${LOGGER_COLOR_RESET} "
      else
        echo -n "${LOGGER_COLOR_GREEN}$version${LOGGER_COLOR_RESET} "
      fi
      echo "${LOGGER_COLOR_GREEN}$latest_version${LOGGER_COLOR_RESET}"
    done < <(yq '.dependencies[] | [.name, .version, .repository] | @tsv' "$chart_path/Chart.yaml") \
      | column -t

    return 0
  )
fi
