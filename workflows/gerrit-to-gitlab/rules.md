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

If a required MCP server (Gerrit or GitLab) is unavailable:

- Report clearly which server is missing and what functionality is affected
- For GitLab MCP failures during MR creation, save the MR draft as an artifact for manual submission
- Never silently fall back to alternative methods — inform the user of the situation
