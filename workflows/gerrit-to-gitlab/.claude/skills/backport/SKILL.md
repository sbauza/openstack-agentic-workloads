---
name: backport
description: Fetch a merged upstream Gerrit change, cherry-pick it to an internal GitLab stable branch, and prepare a merge request summary. Use when backporting upstream OpenStack patches, cherry-picking Gerrit changes, or preparing stable branch merge requests.
---

# Backport

You are backporting a merged upstream OpenStack Gerrit change to an internal GitLab repository stable branch. Your goal is to fetch the change, validate it, apply it via cherry-pick, augment the commit message with traceability metadata, and prepare a merge request for the user to review.

**Agent Collaboration**: Invoke the shared backport specialist persona for analysis:

- **@backport-specialist.md** — Invoke for dependency analysis (step 4) and conflict resolution guidance (step 8) to leverage stable branch knowledge, release mapping, and conflict explanation expertise

This skill supports multi-commit backports: you can run `/backport` multiple times to accumulate cherry-picks on the same branch, then create a single MR containing all commits via `/create-mr`.

**Detailed process reference**: See `references/REFERENCE.md` for the full step-by-step process with all sub-steps, MCP fallback paths, and error handling details.

## Input

The user will provide one of:

- A Gerrit change URL (e.g., `https://review.opendev.org/c/openstack/nova/+/912345`)
- A Gerrit change numeric ID (e.g., `912345`)

## Process Overview

### 1. Parse Input

Extract the change ID from the provided URL or use the numeric ID directly. URL format: `https://review.opendev.org/c/{project}/+/{change_id}`.

### 2. Fetch Change Metadata

Check Gerrit MCP availability via `workflows/shared/scripts/detect-mcp.sh gerrit`. Use MCP if available, otherwise fall back to REST API (`gerrit-fetch-metadata.sh`), then manual entry. Present the change summary (subject, author, project, branch, status) to the user for confirmation.

### 3. Validate Status

Verify the change status is `MERGED`. Do not proceed with non-merged changes.

### 4. Analyze Dependencies and Check for Reverts

- **Revert check** (MCP only): Query for merged reverts of the target change
- **Dependency chain** (MCP only): Check parent commits and topic-related changes
- **Deferred verification**: After cloning (step 7), verify dependencies exist on the target stable branch. Write `deps-{change_id}.md` artifact if missing dependencies found

### 5. Prompt for Target

Check for existing backport branches (`backport/*`). If found, offer to add commits to an existing branch or create a new one. For new branches, ask for GitLab project path and stable branch name. Validate branch exists via GitLab MCP if available.

### 6. Prompt for Metadata

Ask for upstream release name (e.g., Wallaby, Zed, 2024.2) and optional Jira issue key. Skipped for existing backport sessions (metadata inherited).

### 7. Clone and Cherry-Pick

1. **Clone/fetch** the internal GitLab repository (MCP, HTTPS, or SSH failover)
2. **Checkout** the target stable branch and pull latest
3. **Create backport branch**: `backport/<change_id>-to-<stable_branch>` (new sessions only)
4. **Fetch upstream commit** via MCP or `gerrit-git-fetch.sh` refspec
5. **Cherry-pick**: `git cherry-pick -x <commit_hash>`

### 8. Handle Conflicts

If cherry-pick conflicts occur:

1. Identify conflicting files with `git diff --name-only --diff-filter=U`
2. Present each conflict with context and upstream intent explanation
3. Write conflict artifact to `artifacts/gerrit-to-gitlab/conflict-{change_id}.md`
4. Wait for user to resolve, then collect resolution notes for commit message
5. Stage resolved files and `git cherry-pick --continue`
6. Offer abort option: `git cherry-pick --abort`

### 9. Augment Commit Message

Amend the commit message (`git commit --amend`) to append after the cherry-pick line:

```text
Upstream-<Release>: <gerrit-change-url>
Resolves: <Jira-issue-key>          # only if applicable
Conflicts:                           # only if conflicts occurred
 * <file_path>
   <resolution description>
```

### 10. Present MR Summary

Show the merge request summary (title, branches, commit message, changed files). For multi-commit sessions, include a table of all commits on the branch.

### 11. Write Artifact

Save to `artifacts/gerrit-to-gitlab/backport-{change_id}.md` with change metadata, target info, cherry-pick result, session state, and MR draft.

### 12. Offer MR Creation

Offer to create the MR via `/create-mr` or add more commits via another `/backport` run.

## Error Conditions

| Condition | Behavior |
|-----------|----------|
| Change not found | Report: "Could not find Gerrit change {id}. Please verify the URL or ID." |
| Change not MERGED | Report: "This change has status '{status}'. Only merged changes can be backported." |
| Gerrit MCP unavailable | Fall back to REST API metadata fetch, then git refspec fetch |
| GitLab MCP unavailable | Fall back to HTTPS/SSH git operations |
| REST API metadata fetch fails | Fall back to manual metadata entry |
| Git fetch fails (both methods) | Report error with remediation steps |
| SSH key invalid | Report error, allow retry or cancellation |
| Stable branch not found | List available branches (if GitLab MCP available) or skip validation |
| Cherry-pick fails (not conflict) | Report the git error and suggest manual intervention |

## Output

**Artifact**: `artifacts/gerrit-to-gitlab/backport-{change_id}.md`

### Writing Style

Follow the rules in `rules.md`. In particular:

- Be specific — cite change IDs, file paths, and commit hashes
- Explain what the upstream change does before showing the MR summary
- Each error message should be self-contained and actionable
- Distinguish between MCP unavailable (using fallback), network errors, authentication errors, and operation failures
