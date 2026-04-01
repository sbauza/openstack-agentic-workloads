---
name: test
description: Run unit tests or pep8 checks against a backport branch in a containerized environment using openstack-tox-docker. Use to validate backported changes before creating a merge request.
---

# Test

Run tox-based unit tests or pep8 (linting) checks against a backport branch inside a Docker container built from [openstack-tox-docker](https://github.com/gibizer/openstack-tox-docker). This skill validates that backported changes do not introduce regressions or style violations before creating a merge request.

The `/test` skill runs after one or more `/backport` invocations and tests the entire accumulated branch state — not individual commits. Run `/test` multiple times to check different tox environments (e.g., `py3` then `pep8`). The Docker image is built once and reused across runs.

## Input

The user invokes `/test` with no arguments. The skill loads context from the active backport branch and backport artifacts.

## Prerequisites

Before proceeding, verify these conditions:

1. **Backport branch exists**:

   ```bash
   git branch --list 'backport/*'
   ```

   If no backport branch is found: "No backport branch found. Please run `/backport` first to prepare a change for testing."

2. **No unresolved conflicts** on the backport branch:

   ```bash
   git diff --name-only --diff-filter=U
   ```

   If unresolved conflicts exist: "The backport branch has unresolved conflicts. Please resolve them before running tests."

3. **Container runtime available**:

   ```bash
   docker version
   ```

   If docker is not available: "No container runtime found. Docker is required to run tests. Please ensure Docker is installed and accessible in your environment."

## Process

### 1. Load Backport Context

Read the most recent backport artifact from `artifacts/gerrit-to-gitlab/backport-*.md`.

Extract:
- **Backport branch name** (e.g., `backport/912345-to-stable/2024.2`)
- **Target stable branch** (e.g., `stable/2024.2`)
- **GitLab project** (e.g., `internal/nova`)
- **Repository path** (e.g., `/workspace/repos/nova`)

If no backport artifact is found: "No backport artifact found. Please run `/backport` first to prepare a change for testing."

If multiple backport branches exist, present them and ask the user which one to test.

### 2. Prompt for Tox Environment

Ask the user which tox environment to run:

"Which tox environment would you like to run? Common options: `py3` (unit tests), `pep8` (linting), or enter a custom environment name."

After the user selects an environment, validate it exists in the project's `tox.ini`:

```bash
grep -E '^\[testenv:' <repo_path>/tox.ini
```

Also check for the default `[testenv]` section which handles `py3`, `py39`, `py310`, etc.

If the selected environment does not exist:

"The tox environment '{env}' was not found in this project's tox.ini. Available environments are: {list}. Please select another."

### 3. Prompt for Build Script

Check if a Docker image has already been built in this session (the user previously selected a build script).

**If no image context exists** (first `/test` run):

1. Clone the openstack-tox-docker repository if not already cloned:

   ```bash
   git clone https://github.com/gibizer/openstack-tox-docker.git /workspace/repos/openstack-tox-docker
   ```

   Or if already cloned, fetch latest:

   ```bash
   cd /workspace/repos/openstack-tox-docker && git pull
   ```

2. List available build scripts:

   ```bash
   ls /workspace/repos/openstack-tox-docker/build-*.sh
   ```

3. Present the list to the user:

   ```text
   Available openstack-tox-docker build scripts:

   1. build-queens.sh
   2. build-train.sh
   3. build-ussuri.sh
   4. build-wallaby.sh
   5. build-yoga.sh
   6. build-fedora36.sh

   Which build script should be used for testing? Enter the number or name.
   ```

4. Remember the selection for subsequent `/test` runs in this session.

**If image context exists** (subsequent `/test` run): Skip this step — reuse the previously selected build script and image.

### 4. Build Docker Image

Extract the branch name from the selected build script (e.g., `build-wallaby.sh` → `wallaby`).

Determine the Docker image name: `nova-tox-<branch>` (e.g., `nova-tox-wallaby`).

Check if the image already exists locally:

```bash
docker image inspect nova-tox-<branch> > /dev/null 2>&1
```

**If the image exists**: Skip the build. Inform the user: "Docker image `nova-tox-<branch>` already exists. Skipping build."

**If the image does not exist**: Build it:

```bash
cd /workspace/repos/openstack-tox-docker && ./build-<branch>.sh
```

Report build progress. If the build fails:

"Docker image build failed. Error output:\n\n{build_error}\n\nCheck that the Dockerfile for this release is compatible with your environment. You can try a different build script."

Do not proceed with testing if the build fails.

### 5. Run Tox

Change to the repository directory and run tox inside the container:

```bash
cd <repo_path> && docker container run \
    --rm \
    --userns=keep-id \
    -w /build \
    -v "$(pwd):/build:Z" \
    --user "$(id -u):$(id -g)" \
    nova-tox-<branch> \
    tox -e <tox_env>
```

Key flags:
- `--rm`: Remove container after exit
- `--userns=keep-id`: Preserve user ID mapping to prevent permission issues
- `-w /build`: Set working directory inside container
- `-v "$(pwd):/build:Z"`: Mount repository with SELinux relabeling
- `--user "$(id -u):$(id -g)"`: Run as current user to preserve file ownership
- `tox -e <tox_env>`: Run the selected tox environment non-interactively

Capture stdout, stderr, and the exit code.

### 6. Report Results

Parse the tox output and present results to the user.

**Exit code 0 — Tests PASS**:

```text
## Test Results: PASS

**Environment**: {tox_env}
**Branch**: {backport_branch}
**Duration**: {duration}
**Docker Image**: {image_name}

All tests passed.
```

**Exit code non-zero — Tests FAIL**:

For **unit tests** (`py3`, `py39`, `py310`, etc.): Extract failing test names from pytest or stestr output. Look for patterns like `FAILED tests/...::test_name` or `{test_id} ... FAIL`.

```text
## Test Results: FAIL

**Environment**: {tox_env}
**Branch**: {backport_branch}
**Duration**: {duration}
**Docker Image**: {image_name}

### Failed Tests

- {test_name_1}: {failure_reason}
- {test_name_2}: {failure_reason}

### Output (last 50 lines)

{tail of tox output}
```

For **pep8** linting: Extract violations in `file:line:col: code message` format. Present each violation with file path, line number, and rule description.

```text
## Test Results: FAIL

**Environment**: pep8
**Branch**: {backport_branch}
**Duration**: {duration}
**Docker Image**: {image_name}

### Pep8 Violations

| File | Line | Code | Description |
|------|------|------|-------------|
| {file_path} | {line} | {code} | {message} |
| {file_path} | {line} | {code} | {message} |

### Output (last 50 lines)

{tail of tox output}
```

After reporting, offer next steps:

- "Run `/test` again to check another tox environment (e.g., pep8 after py3)."
- "Run `/create-mr` to create the GitLab merge request."

### 7. Write Artifact

Save the test results to `artifacts/gerrit-to-gitlab/test-{branch_id}-{tox_env}.md`:

```markdown
# Test Results: {tox_env} on {backport_branch}

**Date**: {date}
**Environment**: {tox_env}
**Branch**: {backport_branch}
**Target**: {stable_branch}
**GitLab Project**: {gitlab_project}
**Docker Image**: {image_name}
**Status**: {PASS|FAIL}
**Duration**: {duration}

## Summary

{pass/fail summary — for failures, count of failing tests or violations}

## Details

{for unit test failures: list of failing test names with failure output}
{for pep8 violations: table of file/line/code/description}

## Output

{relevant tox output — last 100 lines}
```

The artifact persists across the session. When `/create-mr` is run, it can optionally reference test artifacts in the MR description.

## Error Conditions

| Condition | Behavior |
|-----------|----------|
| No backport branch | Report error, suggest running `/backport` first |
| Unresolved conflicts | Report error, list conflicting files |
| Container runtime unavailable | Report error: "Docker is required to run tests" |
| Docker image build fails | Report build error output, suggest trying a different build script |
| Tox environment not found | List available environments from `tox.ini`, ask user to select another |
| Tox execution fails (non-test error) | Report error (e.g., dependency installation failure), include output |
| Container exits unexpectedly | Report container exit code and last output lines |

## Output

**Artifact**: `artifacts/gerrit-to-gitlab/test-{branch_id}-{tox_env}.md`

### Writing Style

Follow the rules in `rules.md`. In particular:

- Report test results clearly with pass/fail status upfront
- For failures, include enough detail to diagnose the issue without leaving the ACP session
- Error messages must include actionable next steps
