# vim: ft=zsh ts=2 sw=2 sts=2 et

# Post a message to a Slack channel via the Web API.
# Usage: z:slack:post <token> <channel|channel:thread_ts|slack-permalink> <text>
# A Slack archives permalink is accepted in place of channel[:thread_ts] and
# resolved via z:slack:dest; for a thread-reply permalink the parent thread_ts
# is used, so posting replies into the same thread works naturally.
# Outputs: message ts (capture with $() to use with z:slack:update)
function z:slack:post() (
  set -euo pipefail

  local token=${1:?token missing}
  local channel=${2:?channel missing}
  local text=${3:?text missing}
  local thread_ts=""

  if [[ $channel == https://* ]]; then
    channel=$(z:slack:dest "$channel") || return 1
  fi

  if [[ $channel == *:* ]]; then
    thread_ts="${channel#*:}"
    channel="${channel%%:*}"
  fi

  local body
  body=$(jq -n \
    --arg channel "$channel" \
    --arg text "$text" \
    --arg thread_ts "$thread_ts" \
    '{channel: $channel, text: $text} + (if $thread_ts != "" then {thread_ts: $thread_ts} else {} end)')

  # Pass the bearer header via --config stdin so the token never lands in argv.
  local response
  response=$(curl --silent --show-error --max-time 10 \
    -X POST https://slack.com/api/chat.postMessage \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "$body" \
    --config - <<EOF
header = "Authorization: Bearer $token"
EOF
  ) || {
    log::warn "Slack API request failed"
    return 1
  }

  if [[ $(jq -r '.ok' <<< "$response") != "true" ]]; then
    log::warn "Slack API error: $(jq -r '.error // "unknown"' <<< "$response")"
    return 1
  fi

  jq -r '.ts' <<< "$response"
)

# Update an existing Slack message.
# Usage: z:slack:update <token> <channel|channel:thread_ts|slack-permalink> <ts> <text>
# A thread_ts suffix in the channel field is accepted for symmetry with
# z:slack:post and silently discarded — chat.update is keyed on channel + ts.
# A permalink is resolved via z:slack:dest purely to extract the channel; the
# message ts to update must still be passed explicitly as $3.
function z:slack:update() (
  set -euo pipefail

  local token=${1:?token missing}
  local channel=${2:?channel missing}
  local ts=${3:?ts missing}
  local text=${4:?text missing}

  if [[ $channel == https://* ]]; then
    channel=$(z:slack:dest "$channel") || return 1
  fi

  if [[ $channel == *:* ]]; then
    channel="${channel%%:*}"
  fi

  local body
  body=$(jq -n \
    --arg channel "$channel" \
    --arg ts "$ts" \
    --arg text "$text" \
    '{channel: $channel, ts: $ts, text: $text}')

  local response
  response=$(curl --silent --show-error --max-time 10 \
    -X POST https://slack.com/api/chat.update \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "$body" \
    --config - <<EOF
header = "Authorization: Bearer $token"
EOF
  ) || {
    log::warn "Slack API request failed"
    return 1
  }

  if [[ $(jq -r '.ok' <<< "$response") != "true" ]]; then
    log::warn "Slack API error: $(jq -r '.error // "unknown"' <<< "$response")"
    return 1
  fi
)

# Derive a channel or channel:ts destination from a Slack archives URL.
# Usage: z:slack:dest <slack-url>
# Outputs: channel (e.g. C080WHN8287) or channel:ts (e.g. C08KQJATB2S:1779295990.798829)
# Accepts either a bare channel URL (https://*.slack.com/archives/<channel>)
# or a message permalink, which additionally encodes a timestamp:
#   https://*.slack.com/archives/<channel>/p<ts-without-dot>[?thread_ts=<parent-ts>&…]
# For reply permalinks the path ts is the reply's own ts; thread_ts= carries the parent's.
function z:slack:dest() (
  set -euo pipefail

  local url=${1:?url missing}

  if [[ ! $url =~ 'slack\.com/archives/[^/?#]+' ]]; then
    log::warn "Not a Slack archives URL: $url"
    return 1
  fi

  local channel=${url##*/archives/}
  channel=${channel%%[/?#]*}

  if [[ ! $url =~ "/archives/${channel}/p[0-9]{16}([?#]|\$)" ]]; then
    printf '%s\n' "$channel"
    return 0
  fi

  local raw_ts=${url##*/p}
  raw_ts=${raw_ts%%[?#]*}

  local ts
  if [[ $url == *thread_ts=* ]]; then
    local ts_part=${url##*thread_ts=}
    ts=${ts_part%%&*}
    log::info "Reply permalink; using parent ts from thread_ts= ($ts)"
  else
    ts="${raw_ts[1,-7]}.${raw_ts[-6,-1]}"
  fi

  printf '%s:%s\n' "$channel" "$ts"
)

# Set ZNIX_SLACK_CHANNEL for the current shell from a permalink or channel[:ts].
# Usage: z:slack:use <slack-permalink | channel | channel:ts>
function z:slack:use() {
  local dest=${1:?argument missing}

  if [[ $dest == https://* ]]; then
    local resolved
    resolved=$(z:slack:dest "$dest") || return 1
    export ZNIX_SLACK_CHANNEL=$resolved
  else
    export ZNIX_SLACK_CHANNEL=$dest
  fi
  log::info "ZNIX_SLACK_CHANNEL=$ZNIX_SLACK_CHANNEL"
}
