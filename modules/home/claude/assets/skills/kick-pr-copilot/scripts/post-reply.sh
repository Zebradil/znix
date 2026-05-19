#!/usr/bin/env bash
# Post a reply into a GitHub PR review thread, optionally marking the thread resolved.
# Requires: gh (GitHub CLI), jq
# Usage:
#   post-reply.sh --comment-id <databaseId> --body <text> [--resolve]
#
# <databaseId> can be any comment in the target thread; GitHub places the reply
# in the correct thread automatically. The same id is used to look up the
# parent thread's node id when --resolve is passed.

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: post-reply.sh --comment-id <databaseId> --body <text> [--resolve]

  --comment-id   numeric databaseId of any comment in the target thread
  --body         reply text (use $'...' or "$(cat <<EOF ... EOF)" for multi-line)
  --resolve      also mark the thread as resolved after replying
EOF
  exit 2
}

comment_id=""
body=""
resolve=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --comment-id)
      [[ $# -ge 2 ]] || usage
      comment_id="$2"
      shift 2
      ;;
    --body)
      [[ $# -ge 2 ]] || usage
      body="$2"
      shift 2
      ;;
    --resolve)
      resolve=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

[[ -n "$comment_id" ]] || { echo "Missing --comment-id" >&2; usage; }
[[ -n "$body" ]] || { echo "Missing --body" >&2; usage; }

pr_json=$(gh pr view --json number) || {
  echo "Unable to retrieve PR number." >&2
  exit 1
}
pr_number=$(echo "$pr_json" | jq -r '.number')

repo_json=$(gh repo view --json owner,name)
owner=$(echo "$repo_json" | jq -r '.owner.login')
repo=$(echo "$repo_json" | jq -r '.name')

gh api "repos/$owner/$repo/pulls/$pr_number/comments/$comment_id/replies" \
  --method POST \
  --field body="$body" \
  > /dev/null

echo "Posted reply to comment $comment_id in $owner/$repo#$pr_number."

if [[ "$resolve" -eq 1 ]]; then
  thread_id=""
  cursor=""
  while true; do
    # shellcheck disable=SC2016
    response=$(gh api graphql -f query='
      query($owner: String!, $repo: String!, $pr: Int!, $cursor: String) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $pr) {
            reviewThreads(first: 100, after: $cursor) {
              pageInfo { hasNextPage endCursor }
              nodes {
                id
                comments(first: 100) {
                  nodes { databaseId }
                }
              }
            }
          }
        }
      }' -f owner="$owner" -f repo="$repo" -F pr="$pr_number" -f cursor="$cursor")

    if echo "$response" | jq -e '.errors' >/dev/null 2>&1; then
      echo "GitHub GraphQL API returned errors:" >&2
      echo "$response" | jq '.errors' >&2
      exit 1
    fi

    thread_id=$(echo "$response" | jq -r --argjson cid "$comment_id" '
        .data.repository.pullRequest.reviewThreads.nodes[]
        | select(any(.comments.nodes[]; .databaseId == $cid))
        | .id
      ' | head -n1)
    [[ -n "$thread_id" ]] && break

    has_next=$(echo "$response" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
    [[ "$has_next" == "true" ]] || break
    cursor=$(echo "$response" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')
  done

  if [[ -z "$thread_id" ]]; then
    echo "Reply posted, but could not find a review thread containing comment $comment_id; not resolving." >&2
    exit 1
  fi

  # shellcheck disable=SC2016
  gh api graphql -f query='
    mutation($threadId: ID!) {
      resolveReviewThread(input: { threadId: $threadId }) {
        thread { isResolved }
      }
    }' -f threadId="$thread_id" > /dev/null

  echo "Resolved thread $thread_id."
fi
