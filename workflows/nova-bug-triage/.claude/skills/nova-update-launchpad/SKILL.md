---
name: nova-update-launchpad
description: Draft and post triage results to a Launchpad bug with user approval. Use after triage to update the bug status, importance, and add a comment on Launchpad.
---

# Update Launchpad Bug

Draft a Launchpad comment and status/importance changes based on the triage results, preview for user approval, and post to Launchpad.

## Input

Optional bug ID. If omitted, uses the previously triaged bug from the current session.

Examples:
- `/nova-update-launchpad` (uses last triaged bug)
- `/nova-update-launchpad 2112373`

## Process

### Step 1. Load Context

1. Load triage classification from the current session (required — error if no prior `/nova-triage` was run)
2. Load triage report artifact if available (from `/nova-report`)
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

1. Check that `LP_ACCESS_TOKEN` and `LP_ACCESS_SECRET` environment variables are set
2. If credentials are available:
   - Run `workflows/shared/scripts/launchpad-update-bug.py {bug_id}` with the appropriate `--comment`, `--status`, and/or `--importance` arguments
   - Report success with the updated bug URL
3. If credentials are not set:
   - Inform user: "Launchpad OAuth credentials are not configured. Set `LP_ACCESS_TOKEN` and `LP_ACCESS_SECRET` environment variables to enable posting."
   - Proceed to Step 6 (fallback) to generate a manual artifact
4. Handle errors from the script:
   - **Exit code 1 (auth error)**: "Authentication failed. Check your OAuth credentials (LP_ACCESS_TOKEN, LP_ACCESS_SECRET)."
   - **Exit code 3 (API error)**: Report the specific error from the script output. If it mentions 403, suggest the user may need Bug Supervisor role for the proposed status.
   - On failure, proceed to Step 6 (fallback)

### Step 6. Fallback

If posting fails or credentials are not configured:

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
