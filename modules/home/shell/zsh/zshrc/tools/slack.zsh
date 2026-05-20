# vim: ft=zsh ts=2 sw=2 sts=2 et

# Post a message to a Slack channel via the Web API.
# Usage: z:slack:post <token> <channel|channel:thread_ts> <text>
# Outputs: message ts (capture with $() to use with z:slack:update)
function z:slack:post() (
  set -euo pipefail

  local token=${1:?token missing}
  local channel=${2:?channel missing}
  local text=${3:?text missing}
  local thread_ts=""

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
# Usage: z:slack:update <token> <channel|channel:thread_ts> <ts> <text>
# A thread_ts suffix in the channel field is accepted for symmetry with
# z:slack:post and silently discarded — chat.update is keyed on channel + ts.
function z:slack:update() (
  set -euo pipefail

  local token=${1:?token missing}
  local channel=${2:?channel missing}
  local ts=${3:?ts missing}
  local text=${4:?text missing}

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
