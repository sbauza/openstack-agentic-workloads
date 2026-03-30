---
name: gerrit-comment
description: Post a review as comments on a Gerrit change using the Gerrit MCP server
---

# Gerrit Comment

Post review findings as inline and top-level comments on an OpenStack Gerrit change.

## Prerequisites

- The **Gerrit MCP server** must be configured in the ACP session
- A completed review artifact from `/spec-review` or `/code-review` must exist
- The user must provide or confirm the Gerrit change number

## Input

The user will provide one of:

- A Gerrit change number (e.g., `123456`)
- A Gerrit change URL (e.g., `https://review.opendev.org/c/openstack/nova/+/123456`)
- Just confirmation to post after a `/spec-review` or `/code-review` run

If no review artifact exists yet, tell the user to run `/spec-review` or `/code-review` first.

## Process

### 1. Load the Review

Read the most recent review artifact from `artifacts/nova-review/`. If multiple exist, ask the user which one to post.

### 2. Parse the Review into Gerrit Comments

Transform the review into Gerrit-compatible comments:

**Top-level message**:
- Must be a **short summary of 1-2 sentences** that gives the reader the overall picture at a glance (e.g., "Looks good overall, minor nits inline." or "Two blockers: missing RPC version bump and no functional test for the bug. See inline comments.")
- Do NOT paste the full review artifact as the top-level message — the details belong in inline comments
- If there are no inline-worthy findings, the top-level message can be slightly longer but should still stay concise and scannable

**Inline comments** (file-specific findings):
- For each finding that references a specific `file:line`, create an inline comment
- Group comments by file path
- Each comment must be **self-contained and human-readable** — explain what's wrong and why in plain language
- Keep inline comments focused — one issue per comment, one or two sentences

### 3. Present to User for Approval

**CRITICAL: Never post to Gerrit without explicit user approval.**

**The agent must NOT suggest or decide a Code-Review vote.** The human reviewer decides the vote based on their own judgement. The agent provides the comments only.

Show the user exactly what will be posted:

```
## Gerrit Comment Preview

**Change**: https://review.opendev.org/c/openstack/nova/+/{change_number}

### Top-level message:
{1-2 sentence summary}

### Inline comments ({count}):
{list of file:line -> comment}
```

Then ask: "Would you like to post these comments to Gerrit? If so, what Code-Review vote do you want to apply (e.g., +1, +2, -1, 0, or no vote)?"

### 4. Post via Gerrit MCP Server

Once approved, use the Gerrit MCP tools to post:

1. **Post the review** using `mcp__gerrit__set_review` (or equivalent):
   - `change_id`: The change number or ID
   - `message`: The top-level review message
   - `comments`: Map of file paths to inline comment objects with `line` and `message`
   - `labels`: `{"Code-Review": vote}` only if the user explicitly chose a vote

2. **Verify the post** by fetching the change details back and confirming the comment appears

### 5. Report Result

Tell the user:
- Whether the post succeeded
- Link to the change on Gerrit
- The vote that was applied (if any)

## Error Handling

- **MCP server not available**: Tell the user to configure the Gerrit MCP server in their ACP session integrations
- **Authentication failure**: Suggest checking Gerrit credentials in workspace settings
- **Change not found**: Verify the change number and that it's on `review.opendev.org`
- **Post failure**: Show the error, save the formatted comment to `artifacts/nova-review/gerrit-comment-{change}.md` so the user can post manually

## Output

On success, no artifact file is needed — the comment is on Gerrit.

On failure, write the formatted comment to `artifacts/nova-review/gerrit-comment-{change}.md` for manual posting.
