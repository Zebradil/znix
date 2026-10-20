#!/usr/bin/env bash
#
# Lists firing Alertmanager alerts in a compact, agent-readable form. Named
# environments (Alertmanager URL + kubectl context) come from the JSON registry
# at $AM_ALERTS_ENVIRONMENTS, rendered from znix.alertmanager.environments.

set -euo pipefail

usage() {
    cat <<EOF
Usage: am-alerts --list
       am-alerts [--all] [--json] ENV|URL [MATCHER...]

Lists active alerts, hiding silenced and inhibited ones unless --all is given.

  ENV       environment name from --list, or an Alertmanager base URL
  MATCHER   Alertmanager label matcher, ANDed with the others:
              severity=critical  alertname!=Watchdog  severity=~"critical|warning"
  --list    print the known environments: name, Alertmanager URL, kubectl context
  --all     include silenced and inhibited alerts
  --json    print the raw /api/v2/alerts response
EOF
}

die() {
    echo "am-alerts: $*" >&2
    exit 1
}

# Reads the /api/v2/alerts array on stdin. Most severe first, oldest first
# within a severity; alertname and severity are lifted into the headline, so
# they are dropped from the label list.
summarize() {
    jq -r --arg now "$1" '
        def rank: {critical: 0, error: 1, warning: 2, info: 3}[.] // 4;
        def ts: sub("\\.[0-9]+"; "") | fromdateiso8601;
        def age: (($now | tonumber) - (. | ts)) as $s
            | if $s >= 86400 then "\($s / 86400 | floor)d"
              elif $s >= 3600 then "\($s / 3600 | floor)h"
              else "\($s / 60 | floor)m" end;
        "# \(length) alert(s)",
        (sort_by((.labels.severity // "" | rank), .startsAt)[]
            | "",
              "[\(.labels.severity // "none")] \(.labels.alertname) firing \(.startsAt | age) (since \(.startsAt | sub("\\.[0-9]+"; "")))"
                + (if .status.state == "active" then ""
                   else " SUPPRESSED silencedBy=\(.status.silencedBy) inhibitedBy=\(.status.inhibitedBy)" end),
              (.labels | del(.alertname, .severity) | to_entries
                | select(length > 0) | "  labels: \(map("\(.key)=\(.value)") | join(" "))"),
              (.annotations | to_entries[] | "  \(.key): \(.value | gsub("\n"; " "))"))
    '
}

self_test() {
    local out
    out=$(summarize 1000000 <<'EOF'
[
  {"labels": {"alertname": "Old", "severity": "warning", "namespace": "a"},
   "annotations": {"summary": "two\nlines"},
   "startsAt": "1970-01-01T00:00:00.000Z", "status": {"state": "active"}},
  {"labels": {"alertname": "Hot", "severity": "critical"}, "annotations": {},
   "startsAt": "1970-01-12T12:40:00Z",
   "status": {"state": "suppressed", "silencedBy": ["s1"], "inhibitedBy": []}},
  {"labels": {"alertname": "Bare"}, "annotations": {},
   "startsAt": "1970-01-12T13:46:00Z", "status": {"state": "active"}}
]
EOF
    )
    local want
    want=$(cat <<'EOF'
# 3 alert(s)

[critical] Hot firing 1h (since 1970-01-12T12:40:00Z) SUPPRESSED silencedBy=["s1"] inhibitedBy=[]

[warning] Old firing 11d (since 1970-01-01T00:00:00Z)
  labels: namespace=a
  summary: two lines

[none] Bare firing 0m (since 1970-01-12T13:46:00Z)
EOF
    )
    [[ $out == "$want" ]] || die "self-test failed:"$'\n'"$out"
    echo "am-alerts: self-test ok"
}

registry=${AM_ALERTS_ENVIRONMENTS:-}
all=false
json=false
while (($#)); do
    case $1 in
    -h | --help) usage && exit 0 ;;
    --self-test) self_test && exit 0 ;;
    --list)
        [[ -n $registry ]] || die "no environments configured (znix.alertmanager.environments)"
        jq -r '"NAME\tALERTMANAGER\tKUBE_CONTEXT",
            (to_entries[] | "\(.key)\t\(.value.url)\t\(.value.kubeContext // "-")")' "$registry"
        exit 0
        ;;
    --all) all=true && shift ;;
    --json) json=true && shift ;;
    -*) die "unknown flag: $1 (see --help)" ;;
    *) break ;;
    esac
done
(($#)) || {
    usage >&2
    exit 1
}

target=$1
shift
if [[ $target == http://* || $target == https://* ]]; then
    url=$target
    context=-
else
    if [[ -z $registry ]] || ! jq -e --arg n "$target" 'has($n)' "$registry" >/dev/null; then
        die "unknown environment: $target (see am-alerts --list)"
    fi
    url=$(jq -r --arg n "$target" '.[$n].url' "$registry")
    context=$(jq -r --arg n "$target" '.[$n].kubeContext // "-"' "$registry")
fi
url=${url%/}

args=(--silent --show-error --fail-with-body --max-time 20 --get "$url/api/v2/alerts" --data-urlencode active=true)
$all || args+=(--data-urlencode silenced=false --data-urlencode inhibited=false)
for m in "$@"; do
    args+=(--data-urlencode "filter=$m")
done
body=$(curl "${args[@]}") || die "query failed: $body"

if $json; then
    echo "$body"
    exit 0
fi

echo "# environment: $target"
echo "# alertmanager: $url"
echo "# kube-context: $context"
echo "# matchers: ${*:-none}$($all && echo ' (including silenced and inhibited)')"
summarize "$(date +%s)" <<<"$body"
