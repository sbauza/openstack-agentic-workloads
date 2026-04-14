---
name: nova-refine-spec
description: Review and refine a generated nova-spec with structural completeness checks and architectural feedback. Use after create-spec to improve the draft with nova-core and security review.
---

# Refine Spec

You are reviewing and refining an OpenStack Nova specification proposal. Your goal is to help the contributor strengthen their spec by identifying incomplete sections, assessing architectural fit within Nova's design, and interactively improving weak areas.

**Agent Collaboration**: Invoke shared agent personas for specialized review:

- **@nova-core.md** — Invoke for every refinement to assess architectural fit, versioning implications, upgrade safety, and conductor boundary compliance
- **@nova-coresec.md** — Invoke when the spec proposes changes to privsep, policies, or credential handling

## Input

The user will provide one of:

- A path to a generated spec file (e.g., `artifacts/nova-spec-workflow/my-feature.rst`)
- No argument — uses the most recently generated spec in `artifacts/nova-spec-workflow/`

## Process

### 1. Locate the Spec File

- If a path is provided, read the file at that path
- If no argument, find the most recently modified `.rst` file in `artifacts/nova-spec-workflow/`
- If no spec files exist: "No spec found. Run `/nova-create-spec` first to generate a draft."

### 2. Structural Completeness Check

Verify the spec contains all 17 required nova-spec sections:

1. Problem description
2. Use Cases
3. Proposed change
4. Alternatives
5. Data model impact
6. REST API impact
7. Security impact
8. Notifications impact
9. Other end user impact
10. Performance impact
11. Other deployer impact
12. Developer impact
13. Implementation
14. Dependencies
15. Testing
16. Documentation impact
17. References

For each section, assess its status:

- **Complete**: Section has substantive content
- **Thin**: Section has content but lacks detail or specificity
- **TODO**: Section contains only a `.. TODO::` marker
- **Missing**: Section is not present at all

### 3. Architectural Fitness Review

Invoke **@nova-core.md** to assess the spec against Nova's architectural requirements:

- **Versioning compliance**: Does the proposal acknowledge RPC, object, DB, and API versioning implications? If a change requires a new RPC method, DB migration, or API microversion, is it called out?
- **Cell v2 awareness**: Does the proposal work correctly across multiple cells? Does it maintain cell-level isolation where needed?
- **Conductor boundary**: Does it maintain the compute-never-touches-DB invariant? If the feature requires data access from compute, does it route through conductor?
- **Rolling upgrade safety**: Can this be deployed without downtime across mixed-version services? Is there a clear upgrade path if breaking changes are involved?
- **Placement integration**: Does it correctly model any new resources in Placement?
- **Concurrency**: Does it handle the eventlet-to-threads transition properly?

### 4. Security Review (Conditional)

If the spec mentions or implies changes to any of the following, invoke **@nova-coresec.md**:

- `nova/privsep/` — privileged operations
- `nova/policies/` — RBAC policy changes
- Credential handling or secret management
- New network-facing surfaces or API endpoints with security implications

The security review assesses:
- Whether privsep boundaries are correctly maintained
- Whether policy changes alter default access patterns
- Whether credentials are handled securely (no logging, proper scoping)

### 5. Present Findings

Organize findings into three categories:

**Structural Issues**:
- Missing or empty sections that need content
- Thin sections that need more detail
- TODO markers that should be resolved

**Architectural Concerns**:
- Versioning implications not acknowledged
- Conductor boundary violations
- Missing upgrade path for breaking changes
- Cell v2 compatibility issues
- Hidden implementation costs (RPC changes, DB migrations, privsep surfaces, API microversions the spec doesn't mention)

**Suggestions**:
- Areas where more specificity would strengthen the spec
- Cross-project dependencies that should be called out
- Testing considerations not yet addressed

For each finding, explain **what** needs attention and **why** it matters for community review.

### 6. Interactive Refinement Loop

After presenting findings:

a. For each incomplete or weak section, ask the contributor targeted questions:
   - "The Proposed change section mentions a new RPC call but doesn't address versioning. What version bump strategy do you plan for the `compute` RPC API?"
   - "The Data model impact section is empty. Will this feature require new database columns or tables?"

b. Incorporate the contributor's answers directly into the spec RST file.

c. Re-check structural completeness after each round of updates.

d. Repeat until:
   - The contributor says "done", "good", "stop", or similar
   - All critical sections are populated (no TODO markers in Problem description, Use Cases, Proposed change)
   - The contributor explicitly confirms the spec is ready

### 7. Write Updated Spec

- Write the updated RST back to the same file path
- Present a final summary:

  ```
  ## Refinement Complete

  **File**: {path}

  ### Changes Made
  - [List sections that were updated]

  ### Remaining TODOs
  - [List any sections still marked TODO]

  ### Readiness Assessment
  - Structural completeness: X/17 sections populated
  - Architectural review: [PASS / CONCERNS NOTED]
  - Security review: [PASS / NOT NEEDED / CONCERNS NOTED]

  ### Next Steps
  - Run `/nova-blueprint` to add the Launchpad blueprint URL
  - Copy to your nova-specs repo for Gerrit submission
  ```

## Output

- **Artifact**: Updated RST file (same path as input)
- **Session output**: Summary of changes made, remaining TODOs, readiness assessment

## Error Conditions

| Condition | Behavior |
|-----------|----------|
| No spec found | Instruct contributor to run `/nova-create-spec` first |
| Spec is not RST format | Report format error, suggest re-generating with `/nova-create-spec` |

### Writing Style

Follow the rules in `rules.md`. In particular:

- Explain **why** something is a concern, not just **what** the rule says
- Be constructive — suggest specific content for weak sections
- Each finding should be self-contained and actionable
- Distinguish between blockers (versioning violations, missing upgrade path) and suggestions (additional detail, cross-project callouts)
