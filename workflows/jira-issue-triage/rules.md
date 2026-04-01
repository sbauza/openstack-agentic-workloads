# JIRA Issue Triage Workflow Rules

This document contains rules and guidelines specific to the JIRA Issue Triage workflow. These rules extend the repository-wide rules in the root `rules.md`, which apply to all workflows.

The root rules — **Human Always Decides**, **Self-Review Before Presenting**, and **Human-Readable Comments** — are the foundation. The rules below add triage-specific constraints.

## Human Approval Gates

Bug triage involves actions that change the state of JIRA issues. These actions require explicit human approval:

- **Status changes**: Never change an issue's status without the user confirming the proposed change
- **Resolution changes**: Never set or change an issue's resolution without user approval
- **Priority changes**: Never change an issue's priority level without user approval
- **Posting comments**: Never post a comment to JIRA without the user reviewing and approving the full text
- **Marking duplicates**: Never mark an issue as a duplicate without the user confirming the duplicate relationship

When presenting triage results, lay out the proposed classification and JIRA field changes clearly, then ask the user to confirm, modify, or reject.

## JIRA MCP Integration

The JIRA Issue Triage workflow interacts with JIRA exclusively via the Atlassian MCP integration:

1. **Issue Fetching** (`/triage` skill):
   - Uses `jira_get_issue` MCP tool to fetch issue details
   - No separate authentication needed — MCP integration handles auth transparently
   - Issues with restricted security levels will return limited data — inform the user

2. **Duplicate Search** (`/triage` skill):
   - Uses `jira_search` MCP tool with JQL queries
   - No separate authentication needed

3. **Transition Discovery** (`/update-jira` skill):
   - Uses `jira_get_transitions` MCP tool to discover valid status transitions
   - Transition names are included in fallback artifact instructions

4. **Write Operations** (`/update-jira` skill):
   - The Atlassian MCP integration is **read-only** — no write tools are available
   - The `/update-jira` skill always generates a fallback artifact at `artifacts/jira-issue-triage/update-{issue_key}.md` with:
     - Proposed status transition, resolution, and priority changes
     - Full comment text ready for copy-paste
     - Step-by-step instructions for manual updating via the JIRA web UI

### Nova Repository Auto-Clone

The Nova source checkout is expected at `/workspace/repos/nova/`. If missing, the workflow automatically clones it from `https://opendev.org/openstack/nova.git`. This may take a few minutes — inform the user that cloning is in progress.

## Security Handling

### Restricted and Security Issues

- If an issue has a **security level** set, warn the user immediately: "This issue has restricted visibility. Triage details should not be shared publicly."
- If an issue describes potential security vulnerabilities (privilege escalation, injection, credential exposure), warn the user: "This issue may be security-related. Follow the OpenStack Vulnerability Management process."
- Do not include restricted issue details in conversation history or artifacts that might be visible to others

### Credential Management

- The Atlassian MCP integration handles authentication transparently — no manual credential management needed
- Never log or echo any authentication details
- All API communication goes through the MCP integration's secure channel
- If the MCP integration is not configured, degrade gracefully to informing the user to set it up in Workspace Settings

## Writing Style

Follow these guidelines when generating triage comments and reports:

### Be Specific
- Cite the exact evidence from the issue report that led to the classification
- Reference specific file paths and line numbers in the Nova source checkout
- Quote relevant parts of the issue description or comments

### Distinguish Severity
- **Classification**: The validity category (Configuration Issue, RFE, etc.) — this is the primary output
- **Confidence**: High, Medium, or Low — how certain the system is about the classification
- **If uncertain**: State assumptions explicitly and recommend the triager verify

### Be Constructive
- For Configuration Issue: explain what the correct configuration should be
- For Incomplete Report: list the specific questions the reporter should answer
- For RFE: suggest filing a nova-spec and briefly explain why this is a feature request
- For Likely Valid Bug: suggest next steps (assign, tag, link to related issues)

### Keep Output Scannable
- Lead with the classification and a one-sentence rationale
- Details (source references, evidence) follow in separate sections
- Busy triagers should understand the verdict in seconds

## Error Handling

**Clear Error Messages**: Distinguish between:
- "Issue not found" (invalid issue key or deleted issue)
- "Permission denied" (user lacks access to view the issue)
- "JIRA MCP integration unavailable" (MCP not configured or unreachable)
- "Issue has restricted visibility" (security level restricts access)
- "Nova source checkout not found" (auto-clone failed)

**Remediation Steps**: Every error message includes specific next steps:
- Issue not found → verify the issue key is correct (format: PROJECT-NUMBER, e.g., OSPRH-1234)
- Permission denied → check your JIRA access permissions for the project
- MCP unavailable → go to Workspace Settings in Ambient to configure the Atlassian integration
- Restricted visibility → ask someone with appropriate access
- Source checkout missing → check network connectivity (auto-clone may have failed)
