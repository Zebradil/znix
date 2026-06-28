#!/usr/bin/env bash
set -euo pipefail

# Resolve Nix store paths, sign them, and push them to an S3 binary cache.
#
# The single source of the resolve -> sign -> push logic, shared by the local
# `nix run .#cache-push` app and the CI push-nix-cache action.
#
# Configuration is read from the environment (each step is skipped when its
# inputs are empty, so a key-less or credential-less run is a no-op for that
# step):
#   CACHE_S3_URL              s3:// URL for `nix copy --to`     (skip push when empty)
#   CACHE_SIGNING_KEY_FILE    key file for `nix store sign`     (skip signing when empty)
#   AWS_ACCESS_KEY_ID
#   AWS_SECRET_ACCESS_KEY     S3 credentials                    (skip push when empty)
#
# Store paths come from exactly one source:
#   --paths-file FILE   newline-separated, pre-resolved store paths (the CI path)
#   ATTR...             flake attrs to resolve, e.g. checks.aarch64-darwin.foo-build
#   (no args)           every output of `.#checks.<current-system>`

paths_file=""
attrs=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --paths-file) paths_file="$2"; shift 2 ;;
    --paths-file=*) paths_file="${1#*=}"; shift ;;
    --) shift; attrs+=("$@"); break ;;
    *) attrs+=("$1"); shift ;;
  esac
done

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
paths="$workdir/paths.txt"

if [[ -n "$paths_file" ]]; then
  # CI already resolved the valid paths; just normalise.
  sed '/^[[:space:]]*$/d' "$paths_file" | sort -u > "$paths"
else
  if [[ ${#attrs[@]} -eq 0 ]]; then
    system="$(nix eval --raw --impure --expr builtins.currentSystem)"
    echo "No attrs given; resolving every checks.${system}.* output."
    mapfile -t names < <(
      nix eval --raw ".#checks.${system}" \
        --apply 'cs: builtins.concatStringsSep "\n" (builtins.attrNames cs)'
    )
    for n in "${names[@]}"; do attrs+=("checks.${system}.${n}"); done
  fi
  candidates="$workdir/candidates.txt"
  : > "$candidates"
  for attr in "${attrs[@]}"; do
    echo "Resolving store paths for .#${attr}"
    # Instantiate the derivation without building, then take its build closure
    # (outputs included, .drv files excluded).
    drv="$(nix path-info --derivation ".#${attr}" 2>/dev/null || true)"
    if [[ -z "$drv" ]]; then
      echo "::warning::could not resolve a derivation for '${attr}'" >&2
      continue
    fi
    nix-store --query --requisites --include-outputs "$drv" \
      | { grep -v '\.drv$' || true; } >> "$candidates"
  done
  sort -u -o "$candidates" "$candidates"
  # Keep only paths valid in the store, so a partial build still contributes its
  # finished outputs. --print-invalid lists the missing ones in a single call;
  # subtract them from the candidates.
  invalid="$workdir/invalid.txt"
  xargs -r nix-store --check-validity --print-invalid < "$candidates" 2>/dev/null \
    | sort -u > "$invalid"
  comm -23 "$candidates" "$invalid" > "$paths"
fi

if [[ ! -s "$paths" ]]; then
  echo "No valid store paths to publish."
  exit 0
fi

mapfile -t store_paths < "$paths"
echo "Resolved ${#store_paths[@]} store path(s)."

if [[ -n "${CACHE_SIGNING_KEY_FILE:-}" ]]; then
  echo "Signing ${#store_paths[@]} path(s)…"
  nix store sign --key-file "$CACHE_SIGNING_KEY_FILE" --recursive "${store_paths[@]}"
else
  echo "CACHE_SIGNING_KEY_FILE not set — skipping signing."
fi

if [[ -z "${CACHE_S3_URL:-}" ]]; then
  echo "CACHE_S3_URL not set — skipping remote push."
elif [[ "$CACHE_S3_URL" == http://* || "$CACHE_S3_URL" == https://* ]]; then
  # An http(s):// binary cache is read-only; `nix copy --to` cannot upload to it
  # (Determinate Nix segfaults instead of erroring). The push target must be a
  # writable store such as s3://bucket?region=…&endpoint=… — this is usually the
  # value that lived in the old CI CACHE_URL secret, NOT the https pull URL.
  echo "::error::CACHE_S3_URL is '${CACHE_S3_URL}', which looks like a read-only pull URL." >&2
  echo "::error::Set cache-s3-url to the writable s3:// push target (e.g. s3://bucket?region=…&endpoint=…)." >&2
  exit 1
elif [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  echo "::warning::Remote cache push skipped — AWS credentials are not set." >&2
else
  echo "Pushing ${#store_paths[@]} path(s) to ${CACHE_S3_URL}…"
  nix copy --to "$CACHE_S3_URL" "${store_paths[@]}"
fi
