---
name: nova-spec-review
description: Review a nova-specs proposal for architectural soundness, completeness, and alignment with Nova's design. Use when evaluating a nova-spec RST file or Gerrit spec change.
---

# Spec Review

You are reviewing an OpenStack Nova specification proposal. Your goal is to provide a thorough, constructive review that assesses not just the format and structure, but whether the proposed architectural changes genuinely fit into Nova's design and are implementable without hidden costs.

**Agent Collaboration — MANDATORY**: Always invoke **@nova-core.md** for every spec review. This is not optional — nova-core assesses architectural fit, versioning implications, upgrade safety, conductor boundary compliance, and general review principles. Skip this agent only if the user explicitly asks to.

Additionally, invoke **@nova-coresec.md** when the spec proposes changes to privsep, policies, or credential handling.

**Context inheritance**: When invoking subagents, always pass the workflow `rules.md` and `knowledge/nova.md` content as context. Workflow rules and project knowledge take precedence over agent persona guidance.

## Input

The user will provide one of:

- A path to a spec file (e.g., `specs/2026.2/approved/my-feature.rst`)
- A spec pasted inline
- A description of a feature to evaluate against Nova's spec standards

## Process

### 1. Locate and Read the Spec

If a path is given, read it from the nova-specs repo. Check these locations:

- `/workspace/repos/nova-specs/specs/<release>/approved/`
- `/workspace/repos/nova-specs/specs/<release>/implemented/`
- `/workspace/repos/nova-specs/specs/backlog/`

If the nova-specs repo is not available, work with whatever the user provides.

### 1b. Check Gerrit Review History

**Check for Gerrit MCP availability first**: Run `workflows/shared/scripts/detect-mcp.sh gerrit` and parse the JSON output to check the `available` field.

- **If Gerrit MCP is available**: Use Gerrit MCP tools to fetch previous patchset revisions and reviewer comments. This context is essential: the current version of the spec may reflect decisions made in response to earlier reviewer feedback. Understanding the review history helps avoid re-raising points that were already discussed and settled, and highlights any open threads that still need resolution.

- **If Gerrit MCP is unavailable**: Skip the review history check. Note in your final review output (in a dedicated "Review History" section) that the Gerrit review history was not checked due to MCP unavailability, and suggest the user manually inspect the review at `https://review.opendev.org/c/<change-id>` for prior reviewer feedback.

### 1c. Verify Launchpad Blueprint

The spec template requires a Launchpad blueprint URL as the first item in the spec file. Verify that:

- The blueprint URL is present at the top of the spec (e.g., `https://blueprints.launchpad.net/nova/+spec/{name}`)
- The blueprint actually exists — fetch the URL to confirm it resolves

If the blueprint is missing or the link is broken, flag it.

### 2. Structural Completeness Check

Verify the spec contains all required sections per the Nova spec template. Rather than checking against a hardcoded list, read the actual template from the nova-specs repo:

- **Template location**: `/workspace/repos/nova-specs/specs/templates/` (look for the current template)
- If the template is not accessible, check against the standard Nova spec sections (Problem description, Use Cases, Proposed change, Alternatives, Data model impact, REST API impact, Security impact, Notifications impact, Other end user impact, Performance impact, Other deployer impact, Developer impact, Implementation, Dependencies, Testing, Documentation impact, References)

Flag missing or empty sections, but do not treat a format gap the same as a substantive problem.

### 3. Architectural Fitness Review

This is the most important part of the review. Evaluate whether the proposed change genuinely fits Nova's architecture:

- **Versioning compliance**: Does the proposal respect RPC, object, DB, and API versioning rules? Refer to `doc/source/contributor/code-review.rst` for the full rules.
- **Cell v2 awareness**: Does it work correctly across multiple cells?
- **Conductor boundary**: Does it maintain the compute-never-touches-DB invariant?
- **Driver impact**: Does it affect virt drivers? Are changes properly abstracted?
- **Rolling upgrade safety**: Can this be deployed without downtime across mixed-version services?
- **Upgrade path**: Is this a breaking change? If so, does the spec provide a clear upgrade path (e.g., migration steps, deprecation period, compatibility shims)? A missing upgrade path for a breaking change is a blocker.
- **Placement integration**: Does it correctly model resources in Placement?
- **Concurrency**: Does it handle the eventlet-to-threads transition properly?

### 4. Hidden Implementation Cost Analysis

Look beyond the surface description. Many specs propose features without realizing they require:

- **An RPC change** — because new information or a new trigger needs to cross service boundaries
- **A DB schema change** — because something needs to be persisted that isn't today
- **A new privsep surface** — because the feature requires privileged operations on the host
- **An API microversion** — because the user-facing interface changes

If the spec doesn't acknowledge these but they're clearly needed, flag them as blockers. The author may not have realized the full scope of their proposal.

### 5. Cross-Project Impact Assessment

The goal here is to **highlight the need for alignment** with other projects:

- Does this require changes in other OpenStack projects (Neutron, Cinder, Glance, Placement)?
- Flag any cross-project dependency so the author can coordinate early
- Note whether oslo library changes are needed

Do not attempt to track down parallel specs in other projects — just identify where alignment is needed.

### 6. Risk Assessment

Flag high-risk patterns:

- Database migrations that aren't additive-only
- RPC changes that break backward compatibility
- New config options with surprising defaults
- Policy changes that alter default access
- Changes to `nova/privsep/` privileged operations

## Output

Write the review to `artifacts/nova-review/spec-{spec-name}.md` with this structure:

```markdown
# Spec Review: {spec title}

**Spec**: {path or reference}
**Date**: {date}
**Verdict**: {APPROVE / REQUEST_CHANGES / NEEDS_DISCUSSION}

## Summary
{1-2 sentence summary of what the spec proposes and the overall assessment}

## Review History
{If Gerrit MCP was unavailable: note that review history was not checked and provide link for manual inspection}

## Structural Completeness
{Table or checklist of required sections with status — based on the actual template}

## Architectural Review

### Strengths
{What the spec does well}

### Blockers
{Issues that must be resolved — missing versioning considerations, architectural misfit, hidden implementation costs}

### Suggestions
{Improvements that would strengthen the spec but aren't blocking}

## Cross-Project Impact
{Projects that need alignment and why}

## Risk Assessment
{High-risk patterns identified, including hidden RPC/DB/privsep implications}

## Recommended Actions
{Numbered list of specific actions for the author}
```

### Writing Style

Follow the rules in `rules.md`. In particular:

- Write every finding as if speaking to the spec author directly — be a helpful colleague
- Explain **why** something is a problem, not just **what** the rule says
- Each blocker or suggestion should be self-contained — readable without jumping to other sections
- The Summary must be 1-2 sentences that a busy reviewer can scan in seconds
