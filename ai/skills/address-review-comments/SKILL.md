---
name: address-review-comments
description: Fetch, analyze and implement unresolved PR comments
allowed-tools: Bash(gh *), Bash(gh-pr-unresolved-comments *), Read, Grep, Glob
---

1. Use `gh-pr-unresolved-comments` to fetch unresolved PR thread comments
2. For each thread:
   - Figure out the conclusion of the discussion if there are multiple comments
   - Validate if the feedback makes sense
   - Suggest action:
     - If the comment is valid, suggest an implementation plan to address the feedback
     - If the comment is invalid, provide a rationale for why it can be ignored, and suggest a response to the commenter (`gh` can be used to post a comment on the PR)
3. Create an implementation plan addressing valid comments
4. Present the plan for approval before implementing

## Replying to a review thread

Each comment in the output includes a `databaseId`. Use it to post a reply directly into the correct review thread via the REST API (not `gh pr comment`, which adds a top-level comment):

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{databaseId}/replies \
  --method POST \
  --field body="your reply here"
```

The owner, repo, and PR number are already resolved by the fetch script — re-use the same `gh pr view` / `gh repo view` calls to populate them. Reply to **any comment in the thread** (typically the first); GitHub will place it in the correct thread.
