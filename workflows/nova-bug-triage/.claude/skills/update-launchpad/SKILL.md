---
name: update-launchpad
description: Draft and post triage results to a Launchpad bug with user approval
---

# Update Launchpad Bug

Draft a Launchpad comment and status/importance changes based on the triage results, preview for user approval, and post to Launchpad.

## Input

Optional bug ID. If omitted, uses the previously triaged bug from the current session.

Examples:
- `/update-launchpad` (uses last triaged bug)
- `/update-launchpad 2112373`

## Process

### Step 1. Load Context

1. Load triage classification from the current session (required — error if no prior `/triage` was run)
2. Load triage report artifact if available (from `/report`)
3. If a report artifact exists, use its Proposed Launchpad Comment section as the starting draft

### Step 2. Map to Launchpad Fields

Based on the validity category, determine the proposed changes:

| Category | Proposed Status | Proposed Importance |
|----------|----------------|---------------------|
| Configuration Issue | Invalid | (unchanged) |
| Unsupported Feature | Won't Fix | (unchanged) |
| Incomplete Report | Incomplete | (unchanged) |
| Not Reproducible in Master | Invalid | (unchanged) |
| RFE | Invalid | Wishlist |
| Likely Valid Bug | Triaged or Confirmed | Proposed level |

Note: Setting status to "Triaged" or "Won't Fix" requires Nova Bug Supervisor permissions. If the user may not have these permissions, suggest "Confirmed" or "Invalid" as alternatives.

### Step 3. Draft Comment

Write a Launchpad comment summarizing the triage findings:

- **Tone**: Constructive, specific, helpful — write as a Nova community member
- **Structure**:
  1. One-sentence classification (e.g., "This appears to be a configuration issue rather than a code bug.")
  2. Evidence supporting the classification (cite specific details from the report)
  3. For Configuration Issue: explain the correct configuration
  4. For Incomplete Report: list the specific information needed
  5. For RFE: suggest filing a nova-spec and explain why this is a feature request
  6. For Not Reproducible in Master: reference the fix if identifiable
  7. For Likely Valid Bug: note the affected subsystem and proposed importance
- **Do not include**: internal confidence levels, AI references, source file paths (these are for the triager, not the reporter)

### Step 4. Preview for User

Display the complete proposed update:

**Proposed Changes for Bug #{bug_id}:**

- **Status**: {current} → {proposed}
- **Importance**: {current} → {proposed}

**Comment:**
> {full comment text}

**IMPORTANT**: Ask for explicit user approval before posting. Present three options:

1. **Approve** — post as shown
2. **Modify** — user provides changes to the comment or status/importance
3. **Cancel** — abort without posting

If the user chooses to modify, incorporate their changes and re-preview.

### Step 5. Post to Launchpad

**Only after explicit user approval:**

1. Check Launchpad MCP availability via `workflows/shared/scripts/detect-mcp.sh launchpad`
2. If MCP available:
   - Use MCP tools to post the comment and update status/importance
   - Report success with the updated bug URL
3. If MCP unavailable:
   - Inform user that OAuth authentication is needed
   - Prompt for OAuth credentials (consumer key, token, token secret)
   - Post comment via Launchpad REST API: `POST /bugs/{bug_id}/+addcomment`
   - Update status/importance via: `PATCH /nova/+bug/{bug_id}`
   - Handle errors:
     - **401 Unauthorized**: "Authentication failed. Check your OAuth credentials." Offer retry (max 3 attempts).
     - **403 Forbidden**: "Insufficient permissions. You may need Nova Bug Supervisor role for this status change." Suggest an alternative status the user can set.
     - **404 Not Found**: "Bug not found. It may have been deleted or made private."
     - **Network error**: "Cannot reach Launchpad. Check your network connection and try again."
   - Credentials are never stored — cleared immediately after use

### Step 6. Fallback

If posting fails after all attempts (3 retries for auth, or user cancels):

1. Save the drafted update as a fallback artifact at `artifacts/nova-bug-triage/update-{bug_id}.md`
2. Format the artifact with:
   - The proposed status and importance changes
   - The full comment text ready for copy-paste
   - Instructions for manual posting via the Launchpad web UI:
     > 1. Open {web_link}
     > 2. Change Status to: {proposed_status}
     > 3. Change Importance to: {proposed_importance}
     > 4. Paste the comment below into the comment box
     > 5. Click "Save Changes"

Report the fallback artifact path to the user.

## Output

Either:
- Successfully posted update to Launchpad (report the URL)
- Fallback artifact at `artifacts/nova-bug-triage/update-{bug_id}.md`

### Writing Style

Follow the rules in `rules.md`. In particular:

- The Launchpad comment is written for the **bug reporter and Nova community** — not for the triager
- Be respectful and constructive — the reporter took time to file the bug
- Do not mention AI, automation, or internal tooling in the comment
- For Incomplete reports, phrase questions as specific, actionable requests
- For RFEs, acknowledge the idea's value while explaining it needs a spec
