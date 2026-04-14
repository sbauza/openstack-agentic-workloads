# Nova Bug Triage Workflow Rules

This document contains rules and guidelines specific to the Nova Bug Triage workflow. These rules extend the repository-wide rules in the root `rules.md`, which apply to all workflows.

The root rules — **Human Always Decides**, **Self-Review Before Presenting**, and **Human-Readable Comments** — are the foundation. The rules below add triage-specific constraints.

## Human Approval Gates

Bug triage involves actions that change the state of Launchpad bugs. These actions require explicit human approval:

- **Status changes**: Never change a bug's status (Invalid, Won't Fix, Incomplete, Triaged, etc.) without the user confirming the proposed change
- **Importance changes**: Never change a bug's importance level without user approval
- **Posting comments**: Never post a comment to Launchpad without the user reviewing and approving the full text
- **Marking duplicates**: Never mark a bug as a duplicate without the user confirming the duplicate relationship

When presenting triage results, lay out the proposed classification and Launchpad changes clearly, then ask the user to confirm, modify, or reject.

## Launchpad REST API Integration

The Nova Bug Triage workflow interacts with Launchpad exclusively via its REST API:

1. **Bug Fetching** (`/nova-triage` skill):
   - Uses `workflows/shared/scripts/launchpad-fetch-bug.sh` to fetch bug details
   - No authentication needed for public bugs
   - Private bugs will return HTTP 401 — inform the user

2. **Duplicate Search** (`/nova-triage` skill):
   - Uses `curl` against the Launchpad REST API search endpoint
   - No authentication needed

3. **Posting Updates** (`/nova-update-launchpad` skill):
   - Uses `workflows/shared/scripts/launchpad-update-bug.py` with OAuth 1.0a
   - Requires environment variables: `LP_ACCESS_TOKEN`, `LP_ACCESS_SECRET`, and optionally `LP_CONSUMER_KEY`
   - If credentials are not configured, the skill generates a fallback artifact at `artifacts/nova-bug-triage/update-{bug_id}.md` with copy-paste instructions for manual posting

### Nova Repository Auto-Clone

The Nova source checkout is expected at `/workspace/repos/nova/`. If missing, the workflow automatically clones it from `https://opendev.org/openstack/nova.git`. This may take a few minutes — inform the user that cloning is in progress.

## Security Handling

### Private and Security Bugs

- If a bug is marked as private (`"private": true`), warn the user immediately: "This bug is private. Triage details should not be shared publicly."
- If a bug is security-related (`"security_related": true`), warn the user: "This is a security bug. Follow the OpenStack Vulnerability Management process."
- Do not include private bug details in conversation history or artifacts that might be visible to others

### Credential Management

- OAuth credentials are read from environment variables (`LP_ACCESS_TOKEN`, `LP_ACCESS_SECRET`, `LP_CONSUMER_KEY`)
- Never log or echo credential values
- Never hardcode credentials in scripts or artifacts
- All API communication uses HTTPS
- If credentials are not set, degrade gracefully to read-only mode

## Writing Style

Follow these guidelines when generating triage comments and reports:

### Be Specific
- Cite the exact evidence from the bug report that led to the classification
- Reference specific file paths and line numbers in the Nova source checkout
- Quote relevant parts of the bug description or comments

### Distinguish Severity
- **Classification**: The validity category (Configuration Issue, RFE, etc.) — this is the primary output
- **Confidence**: High, Medium, or Low — how certain the system is about the classification
- **If uncertain**: State assumptions explicitly and recommend the triager verify

### Be Constructive
- For Configuration Issue: explain what the correct configuration should be
- For Incomplete Report: list the specific questions the reporter should answer
- For RFE: suggest filing a nova-spec and briefly explain why this is a feature request
- For Likely Valid Bug: suggest next steps (assign, tag, link to related bugs)

### Keep Output Scannable
- Lead with the classification and a one-sentence rationale
- Details (source references, evidence) follow in separate sections
- Busy triagers should understand the verdict in seconds

## Error Handling

**Clear Error Messages**: Distinguish between:
- "Bug not found" (invalid bug ID or deleted bug)
- "Bug is private" (requires authentication to view)
- "Launchpad API unreachable" (network or rate limiting)
- "Authentication failed" (invalid OAuth credentials)
- "Insufficient permissions" (need Bug Supervisor role for some status changes)
- "Nova source checkout not found" (auto-clone failed)

**Remediation Steps**: Every error message includes specific next steps:
- Bug not found → verify the bug ID is correct
- Private bug → authenticate or ask someone with access
- API unreachable → check network, try again later
- Auth failed → verify OAuth credentials (`LP_ACCESS_TOKEN`, `LP_ACCESS_SECRET`)
- Insufficient permissions → ask a Nova Bug Supervisor to make the change
- Source checkout missing → check network connectivity (auto-clone may have failed)
