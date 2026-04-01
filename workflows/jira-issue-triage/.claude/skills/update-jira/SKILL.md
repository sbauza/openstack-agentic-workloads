---
name: update-jira
description: Draft triage results and generate manual JIRA update instructions. Use after triage to prepare status, resolution, and priority changes for a JIRA issue.
---

# Update JIRA Issue

Draft a JIRA comment and proposed status/resolution/priority changes based on the triage results, preview for user approval, and generate a fallback artifact with manual update instructions.

**Note**: The Atlassian MCP integration is read-only — no write tools are available. This skill always generates a fallback artifact with step-by-step instructions for manually updating the issue via the JIRA web UI.

## Input

Optional JIRA issue key. If omitted, uses the previously triaged issue from the current session.

Examples:
- `/update-jira` (uses last triaged issue)
- `/update-jira OSPRH-1234`

## Process

### Step 1. Load Context

1. Load triage classification from the current session (required — error if no prior `/triage` was run)
2. Load triage report artifact if available (from `/report`)
3. If a report artifact exists, use its Proposed JIRA Comment section as the starting draft

### Step 2. Get Available Transitions

Use the `jira_get_transitions` MCP tool for the issue key to discover valid status transitions.

Match the proposed status from the validity category mapping to an available transition name. If the exact proposed status is not available as a transition, note the closest available transition and inform the user.

### Step 3. Map to JIRA Fields

Based on the validity category, determine the proposed changes:

| Category | Proposed Status | Proposed Resolution | Proposed Priority |
|----------|----------------|---------------------|-------------------|
| Configuration Issue | Closed | Won't Do | (unchanged) |
| Unsupported Feature | Closed | Won't Do | (unchanged) |
| Incomplete Report | Waiting for Reporter | (unchanged) | (unchanged) |
| Not Reproducible in Master | Closed | Cannot Reproduce | (unchanged) |
| RFE | Closed | Won't Do | Lowest |
| Likely Valid Bug | Open (Triaged) | (unchanged) | Proposed level |

### Step 4. Draft Comment

Write a JIRA comment summarizing the triage findings:

- **Tone**: Constructive, specific, helpful — write as a Nova community member
- **Structure**:
  1. One-sentence classification (e.g., "This appears to be a configuration issue rather than a code bug.")
  2. Evidence supporting the classification (cite specific details from the report)
  3. For Configuration Issue: explain the correct configuration
  4. For Incomplete Report: list the specific information needed
  5. For RFE: suggest filing a nova-spec and explain why this is a feature request
  6. For Not Reproducible in Master: reference the fix if identifiable
  7. For Likely Valid Bug: note the affected subsystem and proposed priority
- **Do not include**: internal confidence levels, AI references, source file paths (these are for the triager, not the reporter)

### Step 5. Preview for User

Display the complete proposed update:

**Proposed Changes for Issue {key}:**

- **Status**: {current} → {proposed} (transition: "{transition_name}")
- **Resolution**: {current} → {proposed}
- **Priority**: {current} → {proposed}

**Comment:**
> {full comment text}

**IMPORTANT**: Ask for explicit user approval before generating the artifact. Present three options:

1. **Approve** — generate the fallback artifact as shown
2. **Modify** — user provides changes to the comment or proposed fields
3. **Cancel** — abort without generating

If the user chooses to modify, incorporate their changes and re-preview.

### Step 6. Generate Fallback Artifact

**Only after explicit user approval:**

1. Create the `artifacts/jira-issue-triage/` directory if it doesn't exist
2. Generate the fallback artifact at `artifacts/jira-issue-triage/update-{issue_key}.md` with the following structure:

```markdown
# JIRA Update: {issue_key}

**Generated**: {date}
**Issue**: {JIRA web URL}

## Proposed Changes

- **Status transition**: {transition_name}
- **Resolution**: {proposed resolution}
- **Priority**: {proposed priority}

## Comment

Copy and paste the following comment into the JIRA issue:

---

{full comment text}

---

## Manual Update Instructions

1. Open the issue: {JIRA web URL}
2. Click the **"{transition_name}"** button to change the status
3. Set **Resolution** to: {proposed resolution}
4. Set **Priority** to: {proposed priority} (if changed)
5. Scroll to the comment box and paste the comment above
6. Click **Save** or **Submit**
```

3. Report the artifact path to the user:

> Update instructions saved to `artifacts/jira-issue-triage/update-{issue_key}.md`

## Output

Fallback artifact at `artifacts/jira-issue-triage/update-{issue_key}.md`.

### Writing Style

Follow the rules in `rules.md`. In particular:

- The JIRA comment is written for the **issue reporter and Nova community** — not for the triager
- Be respectful and constructive — the reporter took time to file the issue
- Do not mention AI, automation, or internal tooling in the comment
- For Incomplete reports, phrase questions as specific, actionable requests
- For RFEs, acknowledge the idea's value while explaining it needs a spec
