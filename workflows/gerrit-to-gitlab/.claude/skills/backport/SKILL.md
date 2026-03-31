---
name: backport
description: Fetch a merged upstream Gerrit change, cherry-pick it to an internal GitLab stable branch, and prepare a merge request summary
---

# Backport

You are backporting a merged upstream OpenStack Gerrit change to an internal GitLab repository stable branch. Your goal is to fetch the change, validate it, apply it via cherry-pick, augment the commit message with traceability metadata, and prepare a merge request for the user to review.

This skill supports multi-commit backports: you can run `/backport` multiple times to accumulate cherry-picks on the same branch, then create a single MR containing all commits via `/create-mr`.

## Input

The user will provide one of:

- A Gerrit change URL (e.g., `https://review.opendev.org/c/openstack/nova/+/912345`)
- A Gerrit change numeric ID (e.g., `912345`)

## Process

### 1. Parse Input

Extract the change ID from the provided URL or use the numeric ID directly.

- URL format: `https://review.opendev.org/c/{project}/+/{change_id}`
- If the input does not match either format, ask the user to provide a valid Gerrit change URL or ID.

### 2. Fetch Change Metadata

**Check for Gerrit MCP availability**: Run `workflows/shared/scripts/detect-mcp.sh gerrit` and parse the JSON output to check the `available` field.

#### 2a. If Gerrit MCP is Available

Use the Gerrit MCP server to retrieve change details:

- Subject (one-line summary)
- Author (name and email)
- Project (e.g., `openstack/nova`)
- Branch (e.g., `master`, `stable/2024.2`)
- Status (must be `MERGED`)
- Commit message (full text)
- Commit hash (SHA of the merged commit)
- Parent commits (for dependency analysis)
- Topic (if set — for finding related changes)

Present the change summary to the user:

```text
Change: {change_id}
Subject: {subject}
Author: {author}
Project: {project}
Branch: {branch}
Status: {status}
```

Proceed to step 3.

#### 2b. If Gerrit MCP is Unavailable

Fall back to Gerrit REST API metadata fetching:

1. **Call gerrit-fetch-metadata.sh script**:
   
   ```bash
   workflows/shared/scripts/gerrit-fetch-metadata.sh <change_id>
   ```
   
   The script fetches change details from the Gerrit REST API and outputs JSON with:
   - `subject`
   - `author_name`
   - `author_email`
   - `project`
   - `branch`
   - `status`
   - `commit_message`
   - `current_revision` (commit SHA)
   - `parent_commits` (array of parent SHAs)
   - `topic` (if set)

2. **Parse script output**:
   - Exit code 0 = success (JSON on stdout)
   - Exit code 1 = change not found (HTTP 404)
   - Exit code 2 = network/API error
   - Exit code 3 = invalid arguments
   - Exit code 4 = JSON parse error

3. **Handle errors**:
   - **Change not found**: Report "Gerrit change {id} not found. Verify the change ID is correct."
   - **Network error**: Report "Cannot reach review.opendev.org. Check network access, VPN, or firewall." Offer to proceed with manual metadata entry (step 2c).
   - **API error**: Report error details, offer manual metadata entry (step 2c).

4. **Display fetched metadata** to the user:
   
   ```text
   Fetched metadata via Gerrit REST API:
   
   Change: {change_id}
   Subject: {subject}
   Author: {author_name} <{author_email}>
   Project: {project}
   Branch: {branch}
   Status: {status}
   Commit: {current_revision}
   ```

5. **Prompt for confirmation or editing**:
   
   Ask: "Does this metadata look correct? You can:
   - Type 'yes' to proceed
   - Type 'edit' to modify any field
   - Type 'cancel' to abort"
   
   - If **yes**: Proceed to step 3
   - If **edit**: Prompt for each field individually, allowing the user to change values or press Enter to keep the current value
   - If **cancel**: Stop the backport

6. **On success**, proceed to step 3.

#### 2c. Manual Metadata Entry Fallback

If REST API fails or user requests manual entry:

Prompt the user for each required field:
- Subject
- Author name
- Author email
- Project (e.g., openstack/nova)
- Branch (e.g., master)
- Status (should be MERGED)
- Commit message
- Commit SHA (required for git fetch in step 7.4)

Store the manually entered metadata and proceed to step 3.

### 3. Validate Status

Verify the change status is `MERGED`.

- If the status is NOT `MERGED`, inform the user: "This change has status '{status}'. Only merged changes can be backported. Please provide a merged change."
- Do not proceed with non-merged changes.

### 4. Analyze Dependencies and Check for Reverts

Before proceeding with the backport, check for potential issues:

#### 4a. Check for Upstream Reverts

**Only if Gerrit MCP is available**: Query the Gerrit MCP server for changes that revert the target change:

- Search for changes with subject containing "Revert" and referencing the target change ID
- If a revert is found and is also merged, warn the user:

  "Warning: This change was reverted upstream by change {revert_change_id} ('{revert_subject}'). Backporting a reverted change may not be useful. Do you want to proceed anyway? (yes/no)"

- If the user says no, stop the backport

**If Gerrit MCP is unavailable**: Skip the revert check. Note this limitation to the user: "Revert check skipped (Gerrit MCP unavailable). Verify manually that this change was not reverted upstream."

#### 4b. Analyze Dependency Chain

**Only if Gerrit MCP is available**:

1. **Check parent commits**: From the change metadata, examine parent commits. For merge commits (multiple parents), the second parent typically represents the feature branch.

2. **Check topic-related changes**: If the change has a topic set, query the Gerrit MCP server for other merged changes in the same topic:

   ```text
   topic:{topic_name} status:merged project:{project}
   ```

3. **Note dependencies for later verification**: Record parent commit hashes and topic-related change commit hashes. These will be verified against the target stable branch after the repository is cloned in step 7.

   Store internally:
   - Parent commit hashes from change metadata
   - Related change commit hashes from topic query (if any)

**If Gerrit MCP is unavailable**: Skip dependency analysis. Inform the user: "Dependency analysis skipped (Gerrit MCP unavailable). Cherry-pick conflicts may indicate missing prerequisites."

#### 4c. Report Dependencies (deferred)

Actual verification of whether dependencies exist on the target branch happens after the repository is cloned (step 7). Between steps 7.3 (checkout/create backport branch) and 7.5 (cherry-pick), verify dependencies:

1. For each recorded parent/related commit hash, check if it exists on the target stable branch:

   ```bash
   git log --format=%H <stable_branch> | grep <hash>
   ```

2. If missing dependencies are found, present them:

   ```text
   ## Missing Dependencies

   The following changes are not present on {stable_branch}:

   - {change_id_1}: {subject_1} (https://review.opendev.org/c/{project}/+/{change_id_1})
   - {change_id_2}: {subject_2} (https://review.opendev.org/c/{project}/+/{change_id_2})

   These changes may be prerequisites for a clean backport.
   ```

3. Write dependency analysis to `artifacts/gerrit-to-gitlab/deps-{change_id}.md`:

   ```markdown
   # Dependency Analysis: {subject}

   **Gerrit Change**: {change_url}
   **Target Branch**: {stable_branch}
   **Date**: {date}

   ## Missing Dependencies

   | Change | Subject | URL |
   |--------|---------|-----|
   | {id_1} | {subject_1} | {url_1} |
   | {id_2} | {subject_2} | {url_2} |

   ## Recommendation

   Backport the missing dependencies first, in order, before backporting this change.
   ```

4. Ask the user: "Missing dependencies detected. Do you want to proceed anyway (conflicts may be more likely), or backport the dependencies first?"

   - If the user chooses to proceed, continue with the cherry-pick
   - If the user chooses to stop, inform them which changes to backport first and halt

5. If no missing dependencies are found, proceed silently.

### 5. Prompt for Target

**Check for an existing backport branch first.** Look for a local branch matching the pattern `backport/*-to-<stable_branch_pattern>` (e.g., `backport/*-to-stable/2024.2`):

```bash
git branch --list 'backport/*'
```

#### 5a. Existing Backport Branch Found

If one or more backport branches exist, present them to the user:

```text
Existing backport branches found:

1. backport/912345-to-stable/2024.2 (targeting internal/nova stable/2024.2, 2 commits)
2. backport/912346-to-stable/zed (targeting internal/nova stable/zed, 1 commit)

Would you like to add this change to an existing branch, or create a new backport branch?
- Enter the number to add to an existing branch
- Enter "new" to create a new backport branch
```

If the user selects an existing branch:

- Switch to that branch: `git checkout <branch_name>`
- **Skip step 6 (Prompt for Metadata)** — reuse the release name and Jira tracking from the existing branch context. However, still ask: "Does this commit resolve a different Jira issue? If so, provide the issue key. Otherwise, press Enter to reuse the same tracking as the previous commit(s)."
- The GitLab project, stable branch, and upstream release name are inherited from the existing backport session
- Proceed directly to step 7.4 (add upstream remote / fetch) and 7.5 (cherry-pick)

If the user says "new", fall through to the standard prompts below.

#### 5b. No Existing Branch (or User Chose "New")

Ask the user for the backport target:

1. **GitLab project path**: "Which internal GitLab project should receive this backport? (e.g., `internal/nova`)"
2. **Stable branch name**: "Which stable branch should the change be applied to? (e.g., `stable/2024.2`)"

**Check for GitLab MCP availability**: Run `workflows/shared/scripts/detect-mcp.sh gitlab` and parse the JSON output.

- **If GitLab MCP is available**: Validate the stable branch exists using the GitLab MCP server to list branches. If the branch does not exist, list available branches that match `stable/*` and ask the user to select one or provide a different branch name.

- **If GitLab MCP is unavailable**: Skip branch validation. Inform the user: "GitLab MCP unavailable — branch existence will be verified during git operations."

### 6. Prompt for Metadata

Ask the user for commit message metadata:

1. **Upstream release name**: "What is the upstream release name for this change? (e.g., Wallaby, Zed, 2024.2)"
2. **Jira issue**: "Does this backport resolve a Jira issue? If so, provide the issue key (e.g., PROJ-456). Otherwise, say 'none'."

### 7. Clone and Cherry-Pick

#### 7.1. Clone or Fetch Internal Repository

**Check for GitLab MCP availability** (from step 5b check).

**If GitLab MCP is available**:

Clone or fetch the internal GitLab repository if not already available locally:

```bash
git clone <gitlab-repo-url> /workspace/repos/<project-name>
```

Or if already cloned, fetch the latest:

```bash
git fetch origin
```

**If GitLab MCP is unavailable**:

Attempt HTTPS git operations first. If they fail, use the SSH failover helper:

1. **Try HTTPS clone/fetch**:
   
   ```bash
   git clone https://gitlab.example.com/<project-path>.git /workspace/repos/<project-name>
   ```
   
   Or:
   
   ```bash
   git fetch origin
   ```

2. **On HTTPS failure** (authentication error, network error):
   
   Call the SSH failover helper:
   
   ```bash
   workflows/shared/scripts/gitlab-ssh-failover.sh \
     <operation> \
     <gitlab_url> \
     <project_path> \
     <local_path>
   ```
   
   Where:
   - `<operation>`: `clone` or `fetch`
   - `<gitlab_url>`: GitLab instance URL (e.g., `gitlab.example.com`)
   - `<project_path>`: Project path (e.g., `internal/nova`)
   - `<local_path>`: Local repository path (e.g., `/workspace/repos/nova`)
   
   The script will:
   - Prompt the user for an SSH private key file path
   - Validate the key file exists and is readable
   - Retry the git operation with `GIT_SSH_COMMAND="ssh -i <key> -o StrictHostKeyChecking=no"`
   - Return exit code 0 on success, non-zero on failure

3. **Parse script output**:
   - Exit code 0 = success
   - Exit code 1 = SSH key file not found or not readable
   - Exit code 2 = git operation failed even with SSH
   - Exit code 3 = invalid arguments
   - Exit code 4 = user cancelled

4. **Handle errors**:
   - **SSH key error**: Report "SSH key file not found or not readable. Verify the path and permissions."
   - **Git operation failed**: Report "Git operation failed with both HTTPS and SSH. Check GitLab access permissions and network connectivity."
   - **User cancelled**: Stop the backport

5. **On success**, proceed to step 7.2

#### 7.2. Checkout Target Branch

```bash
git checkout <stable_branch>
git pull origin <stable_branch>
```

#### 7.3. Create Backport Branch

**For new backport sessions only**:

```bash
git checkout -b backport/<change_id>-to-<stable_branch>
```

The branch name uses the first change ID to anchor the branch. Subsequent cherry-picks are added to this same branch.

**For existing backport sessions** (selected in step 5a), this step is skipped — the branch was already checked out.

#### 7.4. Fetch Upstream Commit

**Determine fetch method based on Gerrit MCP availability** (checked in step 2):

**If Gerrit MCP is available**:

Add the upstream remote and fetch:

```bash
git remote add upstream https://opendev.org/<project>.git
git fetch upstream
```

**If Gerrit MCP is unavailable**:

Use git fetch with Gerrit's `refs/changes` refspec:

1. **Call gerrit-git-fetch.sh script**:
   
   ```bash
   workflows/shared/scripts/gerrit-git-fetch.sh \
     <change_id> \
     <project> \
     <commit_sha> \
     <local_repo_path>
   ```
   
   The script:
   - Constructs the Gerrit refspec: `refs/changes/{last2}/{change_id}/{patchset}`
   - Fetches the specific ref from review.opendev.org
   - Verifies the fetched commit SHA matches the expected value
   - Returns exit code 0 on success

2. **Parse script output**:
   - Exit code 0 = success (commit fetched and verified)
   - Exit code 1 = fetch failed (refspec not found or network error)
   - Exit code 2 = commit SHA mismatch
   - Exit code 3 = invalid arguments

3. **Handle errors**:
   - **Fetch failed**: Report "Could not fetch commit from Gerrit. The change may have been abandoned or the patchset removed. Verify the change exists and is merged."
   - **SHA mismatch**: Report "Fetched commit SHA does not match expected value. The change metadata may be stale."
   - Offer to abort or continue with manual git commands

4. **On success**, proceed to step 7.5

#### 7.5. Cherry-Pick

```bash
git cherry-pick -x <commit_hash>
```

If the cherry-pick succeeds cleanly, proceed to step 9 (Augment Commit Message).

If the cherry-pick fails due to conflicts, proceed to step 8 (Handle Conflicts).

### 8. Handle Conflicts

If `git cherry-pick -x` exits with a conflict error:

1. **Identify conflicting files**:

   ```bash
   git diff --name-only --diff-filter=U
   ```

2. **Present conflicts clearly** to the user. For each conflicting file:

   - Show the file path
   - Show the conflict regions (the `<<<<<<<`, `=======`, `>>>>>>>` markers and surrounding context)
   - Explain what the upstream change intended to do in that file, based on the original commit message and diff

3. **Provide resolution guidance**:

   - Explain what the conflict markers mean: `<<<<<<< HEAD` is the local (stable branch) version, `=======` separates them, `>>>>>>> <hash>` is the upstream version being cherry-picked
   - Suggest reviewing the upstream change's intent to decide which side to keep or how to merge
   - Remind the user that the goal is to apply the upstream fix while preserving any local modifications

4. **Write conflict artifact** to `artifacts/gerrit-to-gitlab/conflict-{change_id}.md`:

   ```markdown
   # Conflict Report: {subject}

   **Gerrit Change**: {change_url}
   **Target Branch**: {stable_branch}
   **Date**: {date}

   ## Conflicting Files

   {list of files with conflicts}

   ## Conflict Details

   ### {file_path_1}

   {conflict regions with context}

   **Upstream intent**: {what the change was trying to do in this file}

   ### {file_path_2}

   {conflict regions with context}

   ## Resolution Guidance

   - Review each conflict in the context of the upstream change's purpose
   - The upstream change aimed to: {brief summary of change intent}
   - Preserve local modifications where they don't conflict with the fix
   ```

5. **Pause and wait** for the user to resolve conflicts manually. Inform the user:

   "The cherry-pick has conflicts in {N} file(s). Please resolve them in your editor or IDE. When done, let me know and I'll continue."

6. **After user confirms resolution**:

   - Validate no conflict markers remain:

     ```bash
     grep -rn '<<<<<<<' <conflicting_files>
     ```

   - If markers remain, inform the user which files still have unresolved conflicts

   - **Collect conflict resolution notes** for the commit message. For each conflicting file, ask the user:

     "How was the conflict in `{file_path}` resolved? Provide a short description, optionally referencing a Change-Id if the conflict was caused by a missing prerequisite change."

     Example user responses:
     - `Ie09e40d6476dcabda2d599e96701d419e3e8bdf0 convert of ext to privsep`
     - `context drift from recent refactor`
     - `I359a412fcabe9e59c99167b35bb3be6553e5f41b drop of utils.execute()`

     Store the list of `(file_path, resolution_description)` pairs for use in step 9.

   - Stage the resolved files:

     ```bash
     git add <resolved_files>
     ```

   - Continue the cherry-pick:

     ```bash
     git cherry-pick --continue
     ```

7. **Abort option**: If the user wants to abort, run:

   ```bash
   git cherry-pick --abort
   ```

   Inform the user: "Cherry-pick aborted. The backport branch has been reset. You can retry with `/backport` or try a different change."

After successful conflict resolution and cherry-pick continuation, proceed to step 9.

### 9. Augment Commit Message

After a successful cherry-pick, amend the commit message to add traceability tags:

```bash
git commit --amend
```

Append the following lines after the `(cherry picked from commit ...)` line:

```text
Upstream-<Release>: <gerrit-change-url>
Resolves: <Jira-issue-key>
Conflicts:
 * <file_path_1>
   <resolution_description_1>
 * <file_path_2>
   <resolution_description_2>
```

- `Upstream-<Release>:` is always added (e.g., `Upstream-Wallaby: https://review.opendev.org/c/openstack/nova/+/912345`)
- `Resolves:` is only added if the user provided a Jira issue key
- `Conflicts:` is only added if the cherry-pick had merge conflicts (resolved in step 8). Each entry lists the conflicting file path and the user's description of how it was resolved. The description may reference a Change-Id if the conflict was caused by a missing prerequisite change.

**Example** (with conflicts):

```text
(cherry picked from commit a1b2c3d4e5f6)
Upstream-Wallaby: https://review.opendev.org/c/openstack/nova/+/912345
Resolves: PROJ-456
Conflicts:
 * nova/tests/unit/virt/disk/test_api.py
   Ie09e40d6476dcabda2d599e96701d419e3e8bdf0 convert of ext to privsep
 * nova/virt/disk/api.py
   I359a412fcabe9e59c99167b35bb3be6553e5f41b drop of utils.execute()
```

### 10. Present MR Summary

Present the backport result. The summary content varies depending on whether this is a single-commit or multi-commit backport session.

#### Single-commit session (first `/backport` on a new branch)

```text
## Merge Request Summary

**Title**: {subject}
**Source Branch**: backport/{change_id}-to-{stable_branch}
**Target Branch**: {stable_branch}
**GitLab Project**: {gitlab_project}

### Commit Message

{full augmented commit message}

### Changed Files

{list of files modified by the cherry-pick}
```

Ask: "Does this look correct? You can run `/create-mr` to create the GitLab merge request, or run `/backport` again to add more commits to this branch."

#### Multi-commit session (adding to an existing branch)

```text
## Updated Backport Summary

**Source Branch**: {branch_name}
**Target Branch**: {stable_branch}
**GitLab Project**: {gitlab_project}
**Total commits on branch**: {N}

### New Commit Added

**Subject**: {subject}
**Gerrit Change**: {change_url}

{full augmented commit message}

### All Commits on Branch

| # | SHA1 | Subject |
|---|------|---------|
| 1 | {sha1} | {subject_1} |
| 2 | {sha1} | {subject_2} |
| ... | ... | ... |
```

List all commits with:

```bash
git log --format="%H %s" <stable_branch>..<branch_name>
```

Ask: "Commit added. You can run `/backport` again to add more commits, or run `/create-mr` to create the GitLab merge request with all {N} commits."

### 11. Write Artifact

Save the backport summary to `artifacts/gerrit-to-gitlab/backport-{change_id}.md`:

```markdown
# Backport: {subject}

**Gerrit Change**: {change_url}
**Author**: {author}
**Upstream Project**: {project}
**Date**: {date}

## Target

- **GitLab Project**: {gitlab_project}
- **Stable Branch**: {stable_branch}
- **Backport Branch**: {branch_name}

## Cherry-Pick Result

- **Status**: clean
- **Commit**: {cherry_pick_hash}

## Backport Session

- **Commits on branch**: {N}
- **This is commit**: {position} of {N}

## Merge Request Draft

**Title**: {subject}
**Source Branch**: {branch_name}
**Target Branch**: {stable_branch}

### Description

{commit message with traceability tags}

### Changed Files

{list of modified files}
```

Each `/backport` invocation writes its own artifact file keyed by its change ID. The `/create-mr` skill reads the branch state directly to compose the MR description, so no single artifact needs to track all commits.

### 12. Offer MR Creation

After presenting the summary, offer:

- **First commit**: "Would you like to create the GitLab merge request now? Run `/create-mr` to proceed, or run `/backport` again to add more commits to this branch."
- **Subsequent commits**: "Run `/backport` to add more commits, or `/create-mr` to create the merge request with all {N} commits."

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
