# Nova Review Workflow Rules

This document contains rules and guidelines for the Nova Review workflow agent.

## MCP Server Integration

### Gerrit MCP Availability

The Nova Review workflow supports both **Gerrit MCP** and **REST API fallback** modes:

- **With Gerrit MCP**: Full integration - fetch change history, metadata, post reviews programmatically
- **Without Gerrit MCP**: REST API fallback - post reviews using HTTP basic authentication

**At workflow startup**, MCP availability is automatically detected. The agent will report the status and adapt accordingly.

### When Gerrit MCP is Unavailable

If Gerrit MCP is not available or connection fails:

1. **Review Posting** (`/gerrit-comment` skill):
   - Automatically falls back to Gerrit REST API
   - Prompts user for HTTP credentials (username and password)
   - Posts review using `POST /changes/{id}/revisions/current/review`
   - Credentials are never stored - prompted each time, cleared after use
   - On authentication failure (HTTP 401/403), user can retry with different credentials or generate manual artifact
   - Maximum 3 authentication attempts, then falls back to manual artifact generation

2. **Review History** (`/spec-review` and `/code-review` skills):
   - Gerrit review history check is skipped
   - Agent notes in review output that history was not checked
   - Suggests manual inspection at `https://review.opendev.org/c/<change-id>`

3. **Manual Artifact Fallback**:
   - If REST API posting fails or user cancels, agent generates a Markdown artifact
   - Artifact contains formatted review comments ready for manual copy-paste to Gerrit UI
   - Saved to `artifacts/nova-review/gerrit-comment-{change}.md`

### Error Handling

**Clear Error Messages**: Distinguish between:
- "Gerrit MCP unavailable" (use REST API fallback)
- "REST API authentication failed" (invalid credentials)
- "Network error" (cannot reach review.opendev.org)
- "Operation failed" (other issues)

**Remediation Steps**: Every error message includes specific next steps:
- Network errors → check VPN, proxy, firewall
- Authentication errors → verify Gerrit credentials, check account status
- MCP errors → configure MCP server or continue with REST API

### User Cancellation

Users can cancel at any prompt by typing 'cancel':
- During HTTP credential prompting
- During retry confirmation
- Operation halts cleanly, no partial state

### Security

**HTTP Basic Authentication**:
- Credentials prompted via secure input (password hidden)
- Transmitted over HTTPS only
- Cleared from memory immediately after use
- Never logged or stored in artifacts

**No Credential Storage**:
- No gitcookies, API tokens, or passwords persisted
- Every REST API operation prompts for fresh credentials
- Credentials valid only for single session

## Writing Style

Follow these guidelines when generating review artifacts:

### Be Specific
- Cite file paths and line numbers for every finding
- Reference exact Nova conventions or documentation sections
- Provide concrete examples of both the problem and the fix

### Distinguish Severity
- **Blockers**: Versioning violations, missing required tests, architectural misfit
- **Suggestions**: Style improvements, performance optimizations, edge case handling
- **Nits**: Minor naming or formatting preferences

### Reference In-Tree Documentation
- Link to `doc/source/contributor/code-review.rst` for versioning rules
- Reference Nova's in-tree docs rather than duplicating rules
- If docs are incomplete, suggest improving them upstream

### Be Constructive
- Suggest fixes, not just problems
- Explain **why** something is an issue, not just **what** the rule says
- Assume good intent - the author is trying to improve Nova

### Keep Summaries Scannable
- Top-level summary must be 1-2 sentences
- Busy reviewers should understand the verdict in seconds
- Details belong in separate sections, not the summary
