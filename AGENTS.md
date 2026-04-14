# Agent Guidelines for OpenStack Agentic Workflows

This document provides rules and guidance for AI agents making changes to this repository.

## Repository Overview

This repository contains custom ACP (Ambient Code Platform) workflow definitions for OpenStack services. Workflows are loaded via ACP's **Custom Workflow** feature, not via built-in discovery.

**Key directories:**

```text
├── .agents/
│   └── skills/             # Cursor skill discovery (symlinks to .claude/skills/)
├── .cursor/
│   └── rules/              # Cursor rule files (.mdc format)
├── agents/                 # Shared agent personas (reusable across workflows)
│   ├── nova-core.md
│   ├── bug-triager.md
│   ├── backport-specialist.md
│   ├── nova-coresec.md
│   └── openstack-operator.md
├── knowledge/              # Shared project knowledge (referenced by workflows)
│   └── nova.md             # Nova architecture, conventions, versioning rules
├── workflows/              # All workflow definitions
│   ├── nova-review/        # Nova code and spec review
│   ├── nova-bug-triage/    # Nova Launchpad bug triage
│   ├── gerrit-to-gitlab/   # Upstream backport to internal GitLab
│   └── [your-workflow]/    # New workflows go here
├── AGENTS.md               # This file (model-agnostic guidelines)
├── CLAUDE.md               # Pointer to AGENTS.md (Claude-specific)
└── README.md
```

---

## Critical Rules

### 1. Never Modify Multiple Workflows Without Explicit Request

Each workflow is independent. When asked to make changes, clarify which specific workflow(s) should be modified. Do not assume changes to one workflow should propagate to others.

### 2. Always Validate JSON Syntax

The `.ambient/ambient.json` file must be valid JSON. After any edit:

- Ensure no trailing commas
- Ensure all strings are properly quoted
- Ensure the file parses correctly

### 3. Preserve Existing Functionality

When modifying workflows:

- Keep all existing skills and commands unless explicitly asked to remove them
- Maintain backward compatibility with existing artifact paths
- Do not remove skills without explicit instruction

### 4. Follow Markdown Linting Standards

All Markdown files must follow standard linting practices:

- **Blank lines around headings**: Add a blank line before and after every heading
- **Blank lines around lists**: Add a blank line before and after bullet/numbered lists
- **Blank lines around code blocks**: Add a blank line before and after fenced code blocks
- **No trailing whitespace**: Remove spaces at the end of lines
- **Single trailing newline**: Files should end with exactly one blank line
- **Consistent list markers**: Use `-` for unordered lists throughout
- **Fenced code blocks should have a language**

### 5. OpenStack Design Principles

All workflows in this repository must follow these principles:

- **Do not duplicate deterministic checks.** If a linter or CI job (e.g., `tox -e pep8`) already enforces a rule, the workflow must not re-check it with an LLM.
- **Use in-tree docs as the source of truth.** Reference each project's contributor documentation rather than forking rules into the workflow. If the in-tree docs are incomplete, suggest improving them upstream.
- **Model-agnostic where possible.** Project knowledge goes in `AGENTS.md` (usable by any AI tool); `CLAUDE.md` is a thin pointer for Claude-specific tooling.
- **Human decides, agent assists.** Workflows provide analysis and draft comments, but the human makes final decisions (e.g., Gerrit votes). Never automate actions that should require human judgement.

---

## Agent Personas

The `agents/` directory contains shared agent personas — reusable role definitions that workflows can invoke as subagents via the `@agent-name.md` syntax. Each persona file uses YAML frontmatter (`name`, `description`, `tools`) and a structured body defining personality, domain knowledge, and key behaviors.

### Available Personas

| Persona | File | Primary Use |
|---------|------|-------------|
| Nova Core Reviewer | `agents/nova-core.md` | Code review: versioning, conductor boundary, API microversions, upgrade safety, architectural fit |
| OpenStack Bug Triager | `agents/bug-triager.md` | Bug triage: classification, source validation, Launchpad lifecycle |
| Backport Specialist | `agents/backport-specialist.md` | Backporting: dependency analysis, conflict resolution, traceability |
| Nova Core Security | `agents/nova-coresec.md` | Security: privsep, RBAC policies, credential handling, OSSA |
| OpenStack Operator | `agents/openstack-operator.md` | Operations: config issues, deployment topology, upgrade paths |

### How Workflows Use Personas

Skills and commands reference personas with the `@` syntax to invoke them as collaborating subagents:

```markdown
## Process

1. Invoke **@nova-core.md** to assess architectural fit, versioning, and API correctness
2. If the change touches nova/privsep/ or nova/policies/, invoke **@nova-coresec.md**
```

Each `@agent-name.md` reference spawns a subagent with the persona's instructions as its context. This enables multi-perspective analysis without overloading a single agent's context.

### Creating New Personas

When adding a persona:

1. Create the file in `agents/{persona-name}.md`
2. Include YAML frontmatter with `name`, `description`, and `tools`
3. Define personality, communication style, domain knowledge, and key behaviors
4. Reference the persona from workflow skills using `@../../agents/{persona-name}.md`
5. Document the persona in this table

### Guidelines

- **Shared personas** go in `agents/` — use when the persona is relevant to multiple workflows
- **Workflow-specific personas** go in `workflows/{name}/.claude/agents/` — use when tightly coupled to one workflow
- **Don't over-fragment** — each subagent invocation costs context and latency. Use personas when distinct expertise adds value, not for every subtask
- **OpenStack-specific knowledge** — personas should encode domain expertise (versioning rules, Gerrit conventions, oslo patterns) rather than generic software roles

---

## Workflow Structure Requirements

Every workflow **must** have:

```text
workflows/{workflow-name}/
├── .ambient/
│   └── ambient.json       # REQUIRED - must have name, description, systemPrompt, startupPrompt
└── README.md              # Recommended - document the workflow
```

Optional but common:

```text
├── .claude/
│   ├── commands/          # Slash commands (*.md files)
│   └── skills/            # Reusable skills (SKILL.md files)
├── AGENTS.md              # Project-specific reference (model-agnostic)
├── CLAUDE.md              # Pointer to AGENTS.md (for Claude tooling)
├── rules.md               # Behavioral rules for the agent
└── templates/             # Reference templates for artifact generation
```

### Required Fields in ambient.json

| Field | Required | Purpose |
|-------|----------|---------|
| `name` | Yes | Display name in UI (2-5 words) |
| `description` | Yes | Brief explanation (1-3 sentences) |
| `systemPrompt` | Yes | Core instructions defining agent behavior |
| `startupPrompt` | Yes | Initial greeting when workflow activates |
| `results` | No | Maps artifact names to output paths |

---

## Writing SystemPrompts

The `systemPrompt` is the most important part of a workflow. Follow these guidelines:

### Must Include

1. **Role definition**: Who the agent is in the context of the OpenStack project
2. **Available skills/commands**: List every `/skill` or `/command` with its purpose
3. **Workflow phases**: Step-by-step methodology
4. **Output locations**: Where to write artifacts (e.g., `artifacts/{workflow-name}/`)
5. **Workspace navigation block**: Help the agent find files efficiently

### Workspace Navigation Block

Include this pattern in every systemPrompt (customize paths as needed):

```text
WORKSPACE NAVIGATION:
**CRITICAL: Follow these rules to avoid fumbling when looking for files.**

Standard file locations (from workflow root):
- Config: .ambient/ambient.json (ALWAYS at this path)
- Skills: .claude/skills/*/SKILL.md
- Reference: AGENTS.md
- Outputs: artifacts/{workflow-name}/

Tool selection rules:
- Use Read for: Known paths, standard files, files you just created
- Use Glob for: Discovery (finding multiple files by pattern)
- Use Grep for: Content search
```

### Style Guidelines

- Use markdown formatting (headers, lists, code blocks)
- Be specific about agent behavior, not vague
- Include error handling guidance
- Keep under ~5000 characters for readability

---

## Writing Skills

Skills go in `.claude/skills/{skill-name}/SKILL.md`.

### Skill File Structure

```markdown
---
name: skill-name
description: Brief description of what this skill does
---

# Skill Name

[Detailed instructions when this skill is invoked]

## Process
...

## Output
...

### Writing Style
Follow the rules in `rules.md`.
```

### When to Use Skills vs Commands

| Use Commands for | Use Skills for |
|------------------|----------------|
| Single-phase tasks | Complex multi-step workflows |
| Workflow entry points | Reusable knowledge packages |
| User-invoked actions | Context that loads on-demand |

---

## Creating New Workflows

### For a New OpenStack Service

1. Create the directory: `workflows/{service-name}-{purpose}/`
2. Create `.ambient/ambient.json` with all required fields
3. Add `AGENTS.md` with service-specific project reference (architecture, conventions, key paths)
4. Add `CLAUDE.md` as a pointer: `@AGENTS.md`
5. Add `rules.md` with behavioral rules
6. Add skills in `.claude/skills/`
7. Add symlinks in `.agents/skills/` for Cursor discovery (see below)
8. Add `README.md`

### Cursor Skill Symlinks

Every skill in `.claude/skills/` must also be symlinked from the root `.agents/skills/` directory so Cursor can discover it.

**Naming convention**: The symlink name should match the skill directory name. If the skill name is already globally unique (e.g., `nova-code-review`), use it directly. For workflows where skill names could collide with other workflows, add a short workflow prefix (e.g., `gtg-backport`, `jira-triage`).

| Workflow | Symlink convention | Example |
|----------|-------------------|---------|
| gerrit-to-gitlab | `gtg-{skill}` | `gtg-backport` |
| jira-issue-triage | `jira-{skill}` | `jira-triage` |
| nova-bug-triage | same as skill name | `nova-triage` |
| nova-review | same as skill name | `nova-code-review` |
| nova-spec-workflow | same as skill name | `nova-create-spec` |

**Example** — adding a skill `nova-my-skill` to the `nova-review` workflow:

```bash
# 1. Create the skill (Claude Code / ACP path)
mkdir -p workflows/nova-review/.claude/skills/nova-my-skill
# ... write SKILL.md ...

# 2. Symlink for Cursor discovery (same name as the skill directory)
ln -s ../../workflows/nova-review/.claude/skills/nova-my-skill .agents/skills/nova-my-skill
```

The symlink path is always `../../workflows/{workflow}/.claude/skills/{skill}` relative to `.agents/skills/`.

### Checklist for New Workflows

- [ ] `.ambient/ambient.json` exists with all 4 required fields
- [ ] `systemPrompt` includes workspace navigation guidelines
- [ ] `systemPrompt` lists all available skills/commands
- [ ] `systemPrompt` specifies output location (`artifacts/{name}/`)
- [ ] `AGENTS.md` references in-tree docs rather than duplicating rules
- [ ] Skills do not duplicate deterministic checks (linters, CI)
- [ ] Human approval is required before any external action (Gerrit posts, etc.)
- [ ] Skills are symlinked in `.agents/skills/` with workflow prefix
- [ ] `README.md` documents the workflow

---

## Modifying Existing Workflows

### Before Making Changes

1. Read the existing `ambient.json` to understand current behavior
2. Read existing skills to understand the workflow phases
3. Identify what specifically needs to change

### Safe Modification Patterns

**Adding a skill:**

- Create new file in `.claude/skills/{skill-name}/SKILL.md`
- Add the skill to the `systemPrompt` skill list
- Update `results` in ambient.json if new artifacts are created
- Add a symlink in `.agents/skills/{prefix}-{skill-name}` for Cursor discovery

**Modifying systemPrompt:**

- Preserve all existing skills/commands unless removing them
- Keep workspace navigation guidelines
- Maintain the general structure (role, skills, phases, outputs)

**Changing artifact paths:**

- Update both `systemPrompt` and `results` field
- Consider backward compatibility

---

## Testing Changes

Before committing changes:

1. **Validate JSON**: Ensure `.ambient/ambient.json` is valid
2. **Check references**: Skills listed in systemPrompt exist as files
3. **Verify paths**: Output paths in systemPrompt match `results` patterns

### Testing in ACP

Use the "Custom Workflow" feature to test without merging to main:

1. Push your branch to GitHub
2. In ACP, select "Custom Workflow..."
3. Enter the repo URL, your branch name, and path
4. Test the workflow end-to-end

### Custom Workflow Fields

| Field | Value |
|-------|-------|
| **URL** | `https://github.com/sbauza/openstack-agentic-workflows.git` |
| **Branch** | The branch with your changes (e.g., `feature/my-changes`) |
| **Path** | The workflow directory (e.g., `workflows/nova-review`) |

**After creating a PR for a workflow change, always report these three fields to the user** so they can immediately test the changes.

---

## Common Mistakes to Avoid

### Vague SystemPrompts

```json
// ❌ Too vague
"systemPrompt": "You help with OpenStack development"

// ✅ Specific and actionable
"systemPrompt": "You are a Nova community member...\n\n## Skills\n- /nova-code-review\n..."
```

### Duplicating Deterministic Checks

```markdown
<!-- ❌ Re-checking what tox -e pep8 already enforces -->
### N-Code Convention Check
Scan for N310, N311, N312...

<!-- ✅ Focus on human-judgement items -->
### Architectural Fit
Style violations are caught by `tox -e pep8`. Focus on whether
the change fits Nova's architecture and versioning rules.
```

### Automated Decisions That Should Be Human

```markdown
<!-- ❌ Agent decides the vote -->
Map APPROVE to Code-Review +1

<!-- ✅ Human decides -->
Present the review. Ask the user what vote they want to apply.
```

### Inconsistent Paths

```json
// ❌ systemPrompt says one thing, results say another
"systemPrompt": "Write to artifacts/review/",
"results": { "Reviews": "output/reviews/*.md" }

// ✅ Consistent paths
"systemPrompt": "Write to artifacts/nova-review/",
"results": { "Reviews": "artifacts/nova-review/*.md" }
```

---

## Quick Reference

### File Locations

| What | Where | Discovered by |
|------|-------|---------------|
| Workflow config | `workflows/{name}/.ambient/ambient.json` | ACP |
| Skills (source) | `workflows/{name}/.claude/skills/{skill}/SKILL.md` | Claude Code, ACP |
| Skills (symlinks) | `.agents/skills/{prefix}-{skill}/` | Cursor |
| Commands | `workflows/{name}/.claude/commands/*.md` | Claude Code, ACP |
| Project reference | `AGENTS.md` (root and per-workflow) | All tools |
| Behavioral rules | `rules.md` / `.cursor/rules/*.mdc` | Claude Code, ACP / Cursor |
| Artifacts (runtime) | `artifacts/{name}/` | All tools |

### Required ambient.json Fields

```json
{
  "name": "Workflow Name",
  "description": "Brief description",
  "systemPrompt": "You are...\n\n## Skills\n...\n\n## Output\nartifacts/...",
  "startupPrompt": "Welcome! Use /skill to start."
}
```
