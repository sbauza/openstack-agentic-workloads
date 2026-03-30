# Gerrit to GitLab — Project Reference

@.ambient/ambient.json

@rules.md

## Workflow Overview

This workflow enables OpenStack operators to backport merged upstream Gerrit changes to internal GitLab repository stable branches. It automates the fetch-analyze-cherry-pick-MR cycle while keeping the human in control of all external actions.

**Typical flow**:

1. User provides a merged Gerrit change URL or ID
2. Workflow fetches change metadata and validates it is merged
3. Workflow checks for missing dependencies (parent commits, topic-related changes)
4. User specifies the target GitLab project and stable branch
5. Workflow cherry-picks the change and augments the commit message
6. User reviews the MR summary and approves creation
7. Workflow pushes the branch and creates the GitLab merge request

**Multi-commit backport flow** (accumulate multiple changes into one MR):

1. User runs `/backport` with the first Gerrit change — creates a new backport branch
2. User runs `/backport` again with additional changes — detects the existing branch and adds commits to it
3. Repeat step 2 as needed
4. User runs `/create-mr` — creates a single MR containing all accumulated commits

## MCP Server Dependencies

### Gerrit MCP Server

Used for all upstream Gerrit interactions (read-only):

- **Fetch change metadata**: subject, author, project, branch, status, commit message, parent commits
- **Query related changes**: find changes in the same topic (`topic:{name} status:merged`)
- **Fetch patch content**: retrieve the diff for the merged change
- **Check for reverts**: query for changes that revert the target change

**Gerrit instance**: `review.opendev.org`
**Change URL format**: `https://review.opendev.org/c/{project}/+/{change_id}`

### GitLab MCP Server

Used for GitLab API operations:

- **List branches**: validate that the user-specified stable branch exists
- **Create merge request**: submit the backported change as an MR with traceability metadata

Local git operations (clone, checkout, cherry-pick, push) use the **git CLI**, not the GitLab MCP server.

## Git CLI Usage

### Cherry-Pick

```bash
git cherry-pick -x <commit_hash>
```

The `-x` flag appends `(cherry picked from commit <hash>)` to the commit message.

### Commit Message Augmentation

After cherry-pick, amend the commit message to add custom metadata:

```bash
git commit --amend
```

Append these tags after the cherry-pick line:

```text
Upstream-<Release>: <gerrit-change-url>
Resolves: <Jira-issue-key>          # only if applicable
```

### Branch Naming

Backport branches follow this convention:

```text
backport/<change_id>-to-<stable_branch>
```

Example: `backport/912345-to-stable/2024.2`

The branch name uses the first change ID as the anchor. When additional commits are cherry-picked onto the same branch (multi-commit backport), the branch name remains unchanged — the first change ID identifies the backport session.

## Commit Message Format

The final commit message structure after cherry-pick and augmentation:

```text
<original upstream commit message>

(cherry picked from commit <upstream-commit-hash>)
Upstream-<Release>: <gerrit-change-url>
Resolves: <Jira-issue-key>
```

**Example**:

```text
Fix scheduler race condition in live migration

The scheduler could double-book a host when two live migrations
targeted the same destination simultaneously. Add a lock to
serialize placement claim updates.

Change-Id: I1234567890abcdef
Closes-Bug: #2012345

(cherry picked from commit a1b2c3d4e5f6)
Upstream-Wallaby: https://review.opendev.org/c/openstack/nova/+/912345
Resolves: PROJ-456
```

**Rules**:

- `Upstream-<Release>:` is always required. The release name (e.g., Wallaby, Zed, 2024.2) is provided by the user.
- `Resolves:` is optional. Only included when the user specifies a Jira issue key.

## Artifact Output

All artifacts are written to `artifacts/gerrit-to-gitlab/`:

| Artifact | Filename Pattern | When Created |
|----------|-----------------|--------------|
| Backport summary | `backport-{change_id}.md` | After every `/backport` run |
| Conflict report | `conflict-{change_id}.md` | When cherry-pick has conflicts |
| Dependency analysis | `deps-{change_id}.md` | When missing dependencies are detected |
| MR draft (fallback) | `mr-draft-{change_id}.md` | When `/create-mr` fails |

## Workspace Navigation

**CRITICAL: Follow these rules to avoid fumbling when looking for files.**

Standard file locations (from workflow root):

- Config: .ambient/ambient.json (ALWAYS at this path)
- Skills: .claude/skills/*/SKILL.md
- Reference: AGENTS.md (this file)
- Rules: rules.md
- Outputs: artifacts/gerrit-to-gitlab/

The internal GitLab repository may be at:

- `/workspace/repos/<project-name>/` — if added to the ACP session

Tool selection rules:

- Use Read for: Known paths, standard files, files you just created
- Use Glob for: Discovery (finding multiple files by pattern)
- Use Grep for: Content search (finding specific patterns in code)

## OpenStack Context

- **Code review**: Gerrit at `review.opendev.org` (not GitHub PRs)
- **Upstream projects**: `openstack/nova`, `openstack/neutron`, `openstack/cinder`, etc.
- **Stable branches**: Follow `stable/<release>` naming (e.g., `stable/2024.2`, `stable/zed`)
- **Commit conventions**: `Change-Id:` footer, `Closes-Bug:` / `Related-Bug:` for Launchpad references
