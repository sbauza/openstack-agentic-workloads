# Rules

These rules extend the [repository-level rules](../../rules.md) with workflow-specific constraints for backporting.

## Human Approval Gate

**Never create a GitLab merge request without explicit user approval.** The `/create-mr` skill must:

- Preview the exact MR (title, description, source branch, target branch) before any action
- Wait for the user to confirm with a clear "yes" before pushing code or creating the MR
- If the user declines, do not proceed — inform them they can re-run when ready

## Traceability Requirements

Every backported commit message must include:

- The `(cherry picked from commit <hash>)` line added by `git cherry-pick -x`
- An `Upstream-<Release>: <gerrit URL>` tag identifying the upstream source
- Optionally, a `Resolves: <Jira issue key>` tag if the backport resolves an internal issue

Never skip the commit message augmentation step. If the amend fails, halt and inform the user.

## Conflict Transparency

When a cherry-pick produces conflicts:

- Present the conflicting files and conflict regions **before** asking the user to resolve them
- Explain what each conflict means in the context of the upstream change
- Never silently skip or auto-resolve conflicts — the user must make all resolution decisions
- Offer the option to abort (`git cherry-pick --abort`) if the user decides not to proceed

## MCP Server Availability

The workflow supports both **MCP** and **fallback** modes for Gerrit and GitLab integrations.

**At workflow startup**, MCP availability is automatically detected. The agent will report status and adapt accordingly.

### Gerrit MCP Fallback

If Gerrit MCP is unavailable:

1. **Metadata Fetching** (`/backport` skill):
   - Automatically fetches change metadata via Gerrit REST API (`GET /changes/{id}/detail`)
   - Displays fetched metadata (subject, author, status, commit hash) to user for confirmation
   - User can confirm, edit fields, or cancel
   - On REST API failure → falls back to manual metadata entry prompts

2. **Patch Fetching** (`/backport` skill):
   - Uses standard git fetch with Gerrit's `refs/changes` refspec
   - Example: `git fetch https://review.opendev.org/<project> refs/changes/45/912345/3`
   - No authentication required for merged public changes
   - On failure → reports detailed error with remediation steps

### GitLab MCP Fallback

If GitLab MCP is unavailable:

1. **Repository Access** (`/backport` skill):
   - Attempts HTTPS git operations (clone, fetch, ls-remote) first
   - On HTTPS failure → automatically fails over to SSH
   - Prompts user for dedicated SSH private key path
   - Validates key file exists and is readable
   - Retries operation with `GIT_SSH_COMMAND="ssh -i <key> -o StrictHostKeyChecking=no"`
   - On both HTTPS and SSH failure → reports detailed errors with remediation

2. **MR Creation** (`/create-mr` skill):
   - Generates MR draft artifact in Markdown format
   - Includes: git push command, MR title, description, source/target branches
   - Provides manual MR creation instructions for GitLab UI
   - Saved to `artifacts/gerrit-to-gitlab/mr-template-{feature}.md`

### Error Handling

**Clear Error Messages**: Distinguish between:
- "MCP unavailable" (using fallback mechanism)
- "REST API failed" (network or API error)
- "Authentication failed" (git credentials or SSH key issue)
- "Operation failed" (other issues)

**Remediation Steps**: Every error message includes specific next steps:
- Network errors → check VPN, proxy, firewall
- Git credential errors → configure git credential helper, verify access
- SSH errors → verify SSH key registered in GitLab, check key permissions
- Gerrit API errors → verify change exists, check network access to review.opendev.org

### User Cancellation

Users can cancel at any prompt by typing 'cancel':
- During metadata confirmation/editing
- During SSH key path prompting
- During MR preview/approval
- Operation halts cleanly, no partial state

### Security

**SSH Key Handling**:
- User provides path to dedicated SSH private key
- Key should be generated specifically for this workflow (isolation)
- Key file path validated (exists, readable)
- `GIT_SSH_COMMAND` environment variable scoped to current session only
- No key content stored or logged
- StrictHostKeyChecking disabled for automation (user should understand risk)

**No Credential Storage**:
- Git credentials managed by user's git credential helper
- SSH keys provided at use-time, not stored
- No plaintext passwords in artifacts or logs
