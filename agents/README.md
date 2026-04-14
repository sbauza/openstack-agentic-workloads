# Agent Personas

This directory contains reusable agent persona definitions for OpenStack workflows. Each persona encodes domain-specific expertise that workflows invoke as specialized subagents via the `@agent-name.md` syntax.

## Available Personas

### [nova-core.md](nova-core.md) — Nova Core Reviewer

Senior Nova core reviewer covering all aspects of Nova code review:

- **Versioning rules**: RPC version bumps, object versioning (`oslo.versionedobjects`), DB migration constraints, API microversions
- **Architecture**: Conductor boundary enforcement, Cells v2 awareness, Placement integration
- **API layer**: Microversion sequencing, REST conventions, policy registration, schema validation
- **Upgrade safety**: Rolling upgrade compatibility, RPC version pinning, online data migrations, config deprecation cycles
- **Test quality**: Unit test expectations, functional reproducers for regressions (`nova/tests/functional/regressions/`), mock discipline

**Used by**: `nova-review` (`/nova-code-review`, `/nova-spec-review`)

### [nova-coresec.md](nova-coresec.md) — Nova Core Security Reviewer

Security-focused reviewer for Nova changes and bug reports:

- **Privsep**: `oslo.privsep` function scope, privilege escalation checks
- **RBAC**: Policy rule correctness, scope types, least privilege defaults
- **Credentials**: Secret masking in logs, `secret=True` config options, token lifecycle
- **Vulnerability patterns**: Command injection, SQL injection, path traversal, SSRF, token leakage
- **CVE vs hardening**: Distinguishes real vulnerabilities from security hardening — compute host access issues are admin responsibility, not Nova CVEs
- **OSSA process**: VMT coordination, embargoed disclosure, advisory identifiers

**Used by**: `nova-review` (when touching privsep/policies), `nova-bug-triage` (security bugs)

### [bug-triager.md](bug-triager.md) — OpenStack Bug Triager

Experienced bug triage specialist:

- **Validity classification**: Configuration Issue, Unsupported Feature, Incomplete Report, Not Reproducible in Master, RFE, Likely Valid Bug
- **Pattern recognition**: Common "not a bug" patterns (quota exceeded, policy denial, missing service, unmigrated DB)
- **Launchpad lifecycle**: Status transitions, importance levels, Bug Supervisor permissions
- **Source validation**: Always cross-references against the source checkout, never classifies from description alone

**Used by**: `nova-bug-triage` (`/nova-triage`)

### [backport-specialist.md](backport-specialist.md) — Backport Specialist

Cherry-pick and stable branch maintenance expert:

- **Dependency analysis**: Parent commits, topic-related changes, `Depends-On` references
- **Conflict resolution**: Explains *why* conflicts exist (refactored code, missing prerequisite, diverged implementations)
- **Traceability**: `cherry-pick -x`, `Upstream-<Release>:` tags, `Resolves:` tags, `Conflicts:` section
- **Release knowledge**: Release name mapping, stable branch conventions, backport eligibility

**Used by**: `gerrit-to-gitlab` (`/backport`)

### [openstack-operator.md](openstack-operator.md) — OpenStack Operator

Experienced operator perspective for deployment and configuration issues:

- **Deployment topologies**: Single-cell, multi-cell, AZ, regions
- **Misconfiguration patterns**: Common symptoms mapped to config fixes (No valid host, Placement mismatch, libvirt connection)
- **Upgrade knowledge**: DB migration steps, online data migrations, cell mapping, RPC version pinning
- **Log analysis**: Service log patterns, request ID tracing across services

**Used by**: `nova-bug-triage` (config/deployment-related bugs)

## How Personas Work

Workflows reference personas in their skills using the `@` syntax:

```markdown
**Agent Collaboration**:

- **@nova-core.md** — Invoke for every review
- **@nova-coresec.md** — Invoke when the change touches nova/privsep/ or nova/policies/
```

When a skill runs, it can spawn a subagent loaded with the persona's instructions. The persona file becomes the subagent's context, giving it focused domain expertise for its specific task.

### When to Use Personas

- **Use them** when a task benefits from specialized expertise that would clutter the main agent's context (e.g., security review details during a general code review)
- **Don't overuse them** — each subagent invocation costs context and latency. If the main agent can handle the task with its existing knowledge, a persona isn't needed

### Conditional Invocation

Personas are typically invoked conditionally based on what the change touches:

- `@nova-coresec.md` — only when the diff includes `nova/privsep/`, `nova/policies/`, or credential-adjacent code
- `@openstack-operator.md` — only when a bug report suggests a configuration or deployment issue
- `@nova-core.md` — invoked for every code review (broad expertise)

## Creating a New Persona

1. Create a new `.md` file in this directory
2. Add YAML frontmatter with `name`, `description`, and `tools`
3. Structure the body with:
   - **Personality & Communication Style** — how the persona communicates
   - **Key Behaviors** — what it focuses on and prioritizes
   - **Domain Knowledge** — specific expertise areas with concrete details
   - **Review/Triage Priorities** — severity tiers for findings
   - **Signature Phrases** — characteristic language (helps maintain persona consistency)
4. Reference the persona from workflow skills using `@../../agents/{name}.md`
5. Add the persona to the table in the top-level `AGENTS.md`
6. Update this README

### Naming Convention

- Nova-specific personas: `nova-{role}.md` (e.g., `nova-core.md`, `nova-coresec.md`)
- Cross-project personas: `{role}.md` (e.g., `bug-triager.md`, `openstack-operator.md`)
- Use kebab-case, keep names short
