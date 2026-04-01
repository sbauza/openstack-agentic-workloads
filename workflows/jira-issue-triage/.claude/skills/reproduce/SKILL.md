---
name: reproduce
description: Analyze a triaged JIRA issue against the Nova source checkout to assess reproducibility. Use after triage to perform deeper source analysis and verify if the issue exists in current master.
---

# Reproduce an Issue Against the Nova Source

Perform a deeper source-based analysis of a triaged issue to determine whether the problem is reproducible in the current master branch. Examines code paths, existing tests, and recent commits.

## Input

Optional JIRA issue key. If omitted, uses the previously triaged issue from the current session.

Examples:
- `/reproduce` (uses last triaged issue)
- `/reproduce OSPRH-1234`

## Process

### Step 1. Load Context

1. Check if an issue was previously triaged in this session
2. If yes and no issue key provided: use the previously triaged issue's details and classification
3. If issue key provided: fetch issue details (same as `/triage` Step 3) and load any existing triage classification
4. If no prior triage and no issue key: error with "No issue context available. Run `/triage {issue_key}` first, or provide an issue key: `/reproduce {issue_key}`"

### Step 2. Ensure Nova Source Checkout

Check that the Nova source checkout exists at `/workspace/repos/nova/`.

If missing, **automatically clone it**:

```bash
git clone https://opendev.org/openstack/nova.git /workspace/repos/nova
```

Inform the user that cloning is in progress — this may take a few minutes.

### Step 3. Identify Code Paths

Using the issue description, tracebacks, error messages, and triage classification, identify relevant source files in the Nova checkout at `/workspace/repos/nova/`:

1. **From tracebacks**: Extract file paths and function names directly referenced
2. **From error messages**: Search the codebase for the exact error string to find where it's raised
3. **From description**: Search for module names, class names, or API endpoint paths mentioned
4. **From configuration**: If config-related, find the option registration in `nova/conf/` and trace its usage

Use Grep to search the Nova codebase. Report all relevant file paths found.

### Step 4. Check Existing Tests

Search for tests covering the affected code area:

1. Search `nova/tests/unit/` for test files matching the affected module path
2. Search `nova/tests/functional/` for functional tests covering the feature area
3. For each relevant test file found, note:
   - What scenarios it covers
   - Whether the reported scenario has test coverage
   - Any gaps in coverage for the reported issue

### Step 5. Check Recent Changes

Run `git log` in the Nova checkout to find recent activity in the affected area:

1. `git log --oneline -20 -- {affected_files}` — recent commits touching the affected code
2. `git log --oneline --all --grep="{keywords}"` — commits with related keywords
3. For each relevant commit found, note the hash, subject line, and date

### Step 6. Assess Reproducibility

Based on the analysis, produce one of these assessments:

- **Yes**: Evidence suggests the issue is still present in master
  - Code path exists unchanged
  - No related fixes found in git history
  - Tests do not cover the reported scenario

- **No**: Evidence suggests the issue has been fixed
  - Related fix commit found (cite hash and subject)
  - Code path has been significantly refactored
  - Tests now cover the reported scenario

- **Inconclusive**: Source analysis alone is insufficient
  - Changes exist but unclear if they address the exact issue
  - Multiple interacting code paths make static analysis difficult
  - The behavior depends on runtime state or timing

- **Requires Environment**: Issue depends on runtime behavior
  - Hypervisor-specific behavior (libvirt, VMware, etc.)
  - Network-dependent operations
  - Race conditions or timing-sensitive code
  - Requires a running OpenStack deployment to verify

### Step 7. Present Assessment

**Reproducibility Assessment**: {Yes / No / Inconclusive / Requires Environment}

**Summary**: {1-2 sentence explanation}

**Code Paths Examined**:
- {file_path}:{line_numbers} — {what was checked}

**Existing Test Coverage**:
- {test_file} — covers {scenarios}
- Gap: {missing coverage for reported issue}

**Recent Commits**:
- {hash} {subject} ({date})

**Limitations**: {what could not be determined from source analysis alone}

Offer next steps:
- `/report` — include reproduction findings in the triage report
- `/update-jira` — generate manual JIRA update instructions

## Output

The reproducibility assessment is held in session memory for use by `/report`.

No artifact is written by this skill — use `/report` to generate a persistent artifact.

### Writing Style

Follow the rules in `rules.md`. In particular:

- Cite specific file paths and line numbers
- Reference commit hashes for any fixes or related changes found
- Be honest about limitations — state what source analysis can and cannot determine
- Distinguish between "fixed" (commit exists) and "changed" (code modified but fix unclear)
