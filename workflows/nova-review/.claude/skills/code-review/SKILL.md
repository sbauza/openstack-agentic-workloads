---
name: code-review
description: Review Nova code changes for intent correctness, architectural consistency, versioning rules, and testing adequacy
---

# Code Review

You are reviewing OpenStack Nova code changes. Your goal is to ensure that the changes implement the intention described in the commit message, are consistent with their surroundings, and fit correctly into Nova's overall architecture. You'll pay attention to unrelated modifications and flag them. You'll also catch versioning errors and testing gaps that would block a patch during Gerrit review.

**Do not re-check what deterministic tools already enforce.** Style violations (N-codes, import ordering, etc.) are caught by `tox -e pep8`. Focus your review on things that require human judgement.

## Input

The user will provide one of:

- A file path or set of paths to review
- A git diff or patch
- A Gerrit change URL or ID to look up
- A Gerrit topic name (e.g., `bp/my-feature`) — to review a set of related changes
- A description of changes to evaluate

## Process

### 0. Handle Gerrit Topic (if provided)

If the user provides a **Gerrit topic** instead of a single change:

1. **Query all changes for the topic** — use the Gerrit MCP server to list all open changes with that topic (e.g., query `topic:{name} status:open project:openstack/nova`)
2. **Present the list** — show the user all changes in the topic with their subject, change number, and status. Ask which change they want to review in depth.
3. **Read all sibling changes for context** — before reviewing the selected change, read the commit messages and diffs of the other changes in the topic. This gives you the full picture of the feature or fix being implemented across multiple patches. Understanding the complete topic helps you assess whether the selected change makes the right architectural choices and whether responsibilities are split correctly across the patch series.
4. **Proceed to step 1** with the selected change, keeping the sibling context in mind throughout the review. Reference sibling changes when relevant (e.g., "this versioning bump is covered in change 123456").

### 1. Gather Context (Before Reading Code)

Before diving into the code, build context the way an experienced reviewer would:

1. **Read the commit message** — understand the stated intent (bug fix? feature? refactor?)
2. **Follow references** — open the linked bug report, spec, or blueprint. Understand the problem being solved.
3. **Check prior review history** — use the Gerrit MCP server (or the change URL) to look at previous patchset revisions and reviewer comments. This context is essential: a design choice that looks odd in isolation may have been explicitly requested by a previous reviewer. Check whether earlier feedback was addressed or if open discussions are still unresolved
4. **Survey the change shape** — look at which files are modified to get an architectural overview: is there a DB migration? RPC change? API change? New tests?
5. **Check for related changes** — if the change belongs to a Gerrit topic and you haven't already loaded siblings (step 0), query the topic now to understand the full scope

### 2. Verify Feature Approval (if applicable)

If the change implements a feature (not a bug fix or minor refactor), verify that the feature has been approved:

1. **Check commit message tags** — look for `Implements: blueprint {name}` or `Partially-Implements: blueprint {name}`. If present, use the blueprint name to look up the blueprint on Launchpad (`https://blueprints.launchpad.net/nova/+spec/{name}`) and check whether an approved spec is attached.
2. **Check Gerrit topic or hashtag** — the topic name may match a spec. Look for a corresponding spec in the nova-specs repo under `specs/<release>/approved/` or `specs/<release>/implemented/`.
3. **If no evidence found** — if there is no blueprint tag in the commit message, no matching Gerrit topic, and no spec can be found, flag this to the user. Features generally require an approved spec or blueprint before code can land.

### 3. Read the Code in Context

Do not review the diff in isolation. Understand the broader context:

- Read surrounding code to assess whether the change is **locally consistent** with its neighbors
- Consider whether the change is **globally sound** — does it fit Nova's architecture, or is it a locally correct solution that creates a larger problem?
- If reviewing a bug fix, understand the code path that leads to the bug — does the fix address the root cause or just a symptom?
- If the change seems cosmetic or tangential to the stated intent, flag it — unrelated modifications should be in separate patches

### 4. Versioning Rules Check (Blockers)

These are the highest-priority items — violations here will definitely block a patch. Refer to Nova's in-tree versioning documentation for the full rules:

- **In-tree reference**: `doc/source/contributor/code-review.rst` (RPC API versions, Object versions sections)

**RPC Version**:
- Any change to an RPC method signature requires a version bump in the relevant manager
- New RPC arguments must be optional with backward-compatible defaults
- Check `nova/compute/rpcapi.py`, `nova/conductor/rpcapi.py`, `nova/scheduler/rpcapi.py`

**Object Version**:
- Adding/removing/changing fields on a versioned object requires a version bump
- Check `VERSION` constant and `obj_make_compatible()` in `nova/objects/`
- Wireline format must remain stable for rolling upgrades

**Database Schema**:
- Migrations must be additive-only (new columns/tables OK, no removals or type changes)
- Migrations must work online (no table locks, no downtime)

**API Microversion**:
- Any change to request/response schema requires a new microversion

### 5. Conductor Boundary Check

- `nova-compute` must NEVER import from `nova/db/` directly
- All database operations from compute must go through conductor RPC
- Virt drivers must not access the database

### 6. Testing Adequacy Check

Go beyond simply checking for test existence. Assess test **quality**:

- **Coverage depth**: Is there new code that has no associated test cases? Are important branches and error paths covered?
- **Test level**: Are tests at the right abstraction level? Not too shallow (testing nothing), not too deep (testing implementation details)?
- **Mock appropriateness**: Are mocks at the right level? Over-mocking can hide real integration issues; under-mocking can make tests brittle
- **Stability**: Could the test be flaky? Watch for dependencies on ordering, timestamps without proper time mocking, explicit or implicit `sleep` calls, or concurrency via `utils.spawn`
- **Bug fix tests**: Unit tests are generally expected for bug fixes. However, if a functional test reproducer is present and provides good coverage of the fix, a missing unit test can be acceptable — note that the unit test is missing but the coverage seems adequate. The functional test should actually reproduce the bug before the fix and pass after.
- **Feature tests**: New features must have unit tests. Complex features should also have functional tests

### 7. Release Notes Check

Changes that need `reno` release notes:

- New features
- Upgrade-impacting changes
- Security fixes
- Deprecations
- Bug fixes with user-visible behavior changes

### 8. Additional Checks

- **Config options**: New options have proper help text, types, and defaults
- **Concurrency**: Thread-safe patterns, proper use of locks, awareness of the eventlet-to-threads transition

## Output

Write the review to `artifacts/nova-review/code-{topic}.md` with this structure:

```markdown
# Code Review: {brief description}

**Files**: {list of files reviewed}
**Date**: {date}
**Verdict**: {APPROVE / REQUEST_CHANGES / COMMENT}
**Topic**: {Gerrit topic, if applicable — with links to sibling changes}

## Summary
{1-2 sentence summary of what the change does and whether it achieves its stated intent}

## Topic Context
{If part of a topic: brief summary of the sibling changes and how this change fits into the series. Omit if single change.}

## Blockers
{Issues that must be fixed before merge}

### Versioning Violations
{Any RPC/object/DB/API versioning issues}

### Intent or Architecture Issues
{Does the change actually solve the problem? Does it fit Nova's architecture?}

### Testing Gaps
{Missing, inadequate, or potentially unstable tests}

## Suggestions
{Non-blocking improvements}

## Positive Feedback
{What the change does well — acknowledge good patterns}

## Files Reviewed
{Table: file path, change type, notes}
```

### Writing Style

Follow the rules in `rules.md`. In particular:

- Write every finding as if speaking to the patch author directly — be a helpful colleague
- Explain **why** something is a problem, not just **what** the rule says
- Each blocker or suggestion should be self-contained — readable without jumping to other sections
- The Summary must be 1-2 sentences that a busy reviewer can scan in seconds
