---
name: kick-pr-copilot
description: Fetch, analyze and implement unresolved PR comments, then push back and resolve
allowed-tools: Bash(gh *), Bash(gh-pr-unresolved-comments *), Bash(bash */scripts/post-reply.sh*), Read, Grep, Glob
---

## General instructions

1. Use `gh-pr-unresolved-comments` to fetch unresolved PR thread comments
2. Run `git pull`
3. For each thread:
   - Extract action points from the discussion (there may be several comments in the thread)
   - Assess validity of the action points
   - If the action points are valid, implement them, otherwise skip implementation
   - In any case post a reply to the thread using `scripts/post-reply.sh` (see below):
     - confirm if the action points were implemented
     - or explain why the action points are invalid
   - Pass `--resolve` when the thread is fully handled (action point implemented, or the comment was a clear nit/non-issue your reply has put to rest). Leave it off when the thread still needs human attention.
4. Commit the made changes (make sure to not commit changes that were before you started).
5. Push back to the PR branch
6. Use `gh pr edit --add-reviewer '@copilot'` to request review from the GitHub Copilot.

## Replying to a review thread

Each comment in the output of `gh-pr-unresolved-comments` includes a `databaseId`. Use `scripts/post-reply.sh` to post a reply (and optionally resolve the thread) without hand-crafting `gh api` calls:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/post-reply.sh \
  --comment-id <databaseId> \
  --body "your reply here" \
  [--resolve]
```

- `--comment-id` accepts the `databaseId` of **any** comment in the thread; GitHub places the reply in the correct thread.
- `--resolve` additionally marks the thread as resolved via the GraphQL `resolveReviewThread` mutation (looked up from the comment's parent thread).

Do **not** use `gh pr comment` — it creates a top-level PR comment instead of a threaded reply.
