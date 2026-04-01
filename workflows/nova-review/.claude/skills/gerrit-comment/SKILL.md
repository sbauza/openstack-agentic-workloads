---
name: gerrit-comment
description: Post a review as comments on a Gerrit change using the Gerrit MCP server or REST API fallback. Use after completing a code-review or spec-review to publish findings to Gerrit.
---

# Gerrit Comment

Post review findings as inline and top-level comments on an OpenStack Gerrit change.

## Prerequisites

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
- **Every inline comment must set the `"unresolved"` field.** Default is `true` (unresolved), but the user may request `false` (resolved). The Gerrit API defaults to resolved if this field is omitted, so it must always be explicitly set

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

Then ask: "Would you like to post these comments to Gerrit? If so:
1. What Code-Review vote do you want to apply (e.g., +1, +2, -1, 0, or no vote)?
2. Should the inline comments be posted as **unresolved** (default) or **resolved**?"

### 4. Check MCP Availability and Post Review

**Check for Gerrit MCP availability**: Run `workflows/shared/scripts/detect-mcp.sh gerrit` and parse the JSON output to check the `available` field.

#### 4a. If Gerrit MCP is Available

Use the Gerrit MCP tools to post:

1. **Post the review** using `mcp__gerrit__set_review` (or equivalent):
   - `change_id`: The change number or ID
   - `message`: The top-level review message
   - `comments`: Map of file paths to inline comment objects with `line`, `message`, and `unresolved: true`
   - `labels`: `{"Code-Review": vote}` only if the user explicitly chose a vote

2. **Verify the post** by fetching the change details back and confirming the comment appears

3. **Report success** — proceed to step 5

#### 4b. If Gerrit MCP is Unavailable

Fall back to Gerrit REST API posting:

1. **Build the review JSON file** with the top-level message, inline comments, and optional labels. Every inline comment **must** explicitly set the `"unresolved"` field (`true` by default, unless the user requested resolved):

   ```json
   {
     "message": "Top-level review summary (1-2 sentences)",
     "comments": {
       "path/to/file.py": [
         {"line": 42, "message": "This looks wrong because...", "unresolved": true},
         {"line": 55, "message": "Consider using...", "unresolved": true}
       ],
       "other/file.py": [
         {"line": 10, "message": "Missing error handling", "unresolved": true}
       ]
     },
     "labels": {"Code-Review": 1}
   }
   ```

   **CRITICAL**: Always explicitly set the `"unresolved"` field on every inline comment. Use `true` (the default) unless the user asked for resolved comments. The Gerrit API defaults to `false` (resolved) if this field is omitted, which hides comments from the reviewer's attention.

   Write this JSON to a temporary file (e.g., `/tmp/review-{change_id}.json`).

2. **Call the gerrit-post-review.sh script**:

   ```bash
   workflows/shared/scripts/gerrit-post-review.sh <change_id> <review_json_file>
   ```

   Where:
   - `<change_id>`: The Gerrit change number
   - `<review_json_file>`: Path to the JSON file built above

3. **Parse the script output**:
   - Exit code 0 = success
   - Exit code 1 = authentication failure (HTTP 401/403)
   - Exit code 2 = network/API error
   - Exit code 3 = invalid arguments
   
   The script outputs JSON with `success`, `http_status`, and `error_message` fields.

4. **Handle authentication failure** (exit code 1):
   - Inform the user: "Authentication failed. The credentials you provided were rejected by Gerrit (HTTP {status})."
   - Offer retry: "Would you like to retry with different credentials? (yes/no/cancel)"
   - Maximum 3 retry attempts
   - On 3rd failure or user cancellation, fall back to manual artifact (step 4c)

5. **Handle network/API error** (exit code 2):
   - Report the error message from the script
   - Suggest remediation: "Check network access to review.opendev.org. VPN or firewall may be blocking the request."
   - Fall back to manual artifact (step 4c)

6. **On success**, proceed to step 5

#### 4c. Manual Artifact Fallback

If REST API posting fails or user cancels:

Write the formatted comment to `artifacts/nova-review/gerrit-comment-{change}.md`:

```markdown
# Gerrit Comment: Change {change_number}

**Change URL**: https://review.opendev.org/c/openstack/nova/+/{change_number}
**Date**: {date}
**Vote**: {vote or "No vote"}

## Top-Level Message

{top_level_message}

## Inline Comments

### {file_path_1}

**Line {line}**: {comment}

**Line {line}**: {comment}

### {file_path_2}

**Line {line}**: {comment}

## Manual Posting Instructions

1. Open the change in your browser: https://review.opendev.org/c/openstack/nova/+/{change_number}
2. Click "Reply" button
3. Copy the top-level message into the comment box
4. For each inline comment:
   - Click on the line number in the file diff view
   - Click "Draft" to add a comment
   - Paste the comment text
5. Select Code-Review vote: {vote or "No vote"}
6. Click "Send" to post the review
```

Inform the user: "Failed to post review to Gerrit. The formatted comment has been saved to `artifacts/nova-review/gerrit-comment-{change}.md` for manual posting."

### 5. Report Result

**On success**:

Tell the user:
- Whether the post succeeded
- Link to the change on Gerrit
- The vote that was applied (if any)
- The method used (MCP or REST API)

Example:
```
Review posted successfully via {Gerrit MCP | REST API}!

**Change**: https://review.opendev.org/c/openstack/nova/+/{change_number}
**Vote**: {vote or "No vote"}
**Comments**: {N} inline, 1 top-level
```

**On failure**:

Inform the user that the review was saved to an artifact file for manual posting, and provide the file path.

## Error Conditions

| Condition | Behavior |
|-----------|----------|
| No review artifact found | Tell user to run `/spec-review` or `/code-review` first |
| MCP unavailable, REST API succeeds | Post via REST API, report success |
| MCP unavailable, REST API auth fails | Retry up to 3 times, then generate manual artifact |
| MCP unavailable, REST API network error | Generate manual artifact with error details |
| User declines to post | Do not proceed; artifact already exists from earlier skill |
| User cancels during retry | Generate manual artifact |

## Output

- **On success**: No artifact file needed — the comment is on Gerrit
- **On failure**: `artifacts/nova-review/gerrit-comment-{change}.md` with manual posting instructions

### Writing Style

Follow the rules in `rules.md`. In particular:

- The comment preview must show exactly what will be posted — no surprises
- Error messages must include actionable next steps with specific remediation guidance
- Distinguish between authentication errors, network errors, and API errors
