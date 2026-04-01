# OpenStack Agentic Workloads

Custom workflow repository for OpenStack services, primarily consumed by the [Ambient Code Platform](https://ambient.code) (ACP).

## Overview

This repository contains ACP workflow definitions tailored for OpenStack development. Each workflow provides structured processes — skills, rules, and project-specific knowledge — that guide AI agents through complex OpenStack tasks like code review, spec authoring, bug triage, backporting, and Gerrit interaction.

The platform automatically discovers workflows from this repository. Any directory under `workflows/` with a valid `.ambient/ambient.json` file appears in the ACP UI.

## Available Workflows

| Workflow | Description | Skills |
|----------|-------------|--------|
| [**nova-review**](workflows/nova-review/) | Review Nova code changes and nova-specs proposals against project conventions and architecture | `/spec-review`, `/code-review`, `/gerrit-comment` |
| [**nova-bug-triage**](workflows/nova-bug-triage/) | Triage Nova Launchpad bug reports by validating whether they describe genuine defects or fall into invalid categories | `/triage`, `/reproduce`, `/report`, `/update-launchpad` |
| [**nova-spec-workflow**](workflows/nova-spec-workflow/) | Generate well-structured nova-spec proposals from JIRA RFE tickets or free-form feature descriptions with architectural review | `/create-spec`, `/refine-spec`, `/blueprint` |
| [**gerrit-to-gitlab**](workflows/gerrit-to-gitlab/) | Backport merged upstream OpenStack Gerrit changes to internal GitLab repository stable branches | `/backport`, `/test`, `/create-mr` |

## Using Workflows

This repository is designed to be consumed via the **Custom Workflow** feature in ACP:

1. In your ACP session, select **"Custom Workflow..."**
2. Fill in the fields:
   - **URL**: `https://github.com/sbauza/openstack-agentic-workloads.git`
   - **Branch**: `main` (or a feature branch for testing)
   - **Path**: path to the workflow directory (e.g., `workflows/nova-review`)
3. Click **"Load Workflow"**

## Shared Knowledge

The `knowledge/` directory contains shared project reference files that multiple workflows depend on. This avoids duplicating architecture, conventions, and design rules across workflows.

| File | Contents |
|------|----------|
| [`knowledge/nova.md`](knowledge/nova.md) | Nova architecture, directory structure, versioning rules, core services, coding conventions, virt drivers, external dependencies, and commit conventions |

Workflows that need Nova domain knowledge (e.g., `nova-review`, `nova-bug-triage`, `nova-spec-workflow`) reference `knowledge/nova.md` via `@../../knowledge/nova.md` in their `AGENTS.md` and add only workflow-specific content locally. New Nova-related workflows should follow the same pattern rather than duplicating the shared reference.

## Agent Personas

The `agents/` directory contains reusable agent persona definitions that workflows can invoke as specialized subagents. Each persona encodes OpenStack domain expertise — versioning rules, triage patterns, security threat models — rather than generic software roles.

| Persona | File | Used By |
|---------|------|---------|
| Nova Core Reviewer | [`nova-core.md`](agents/nova-core.md) | nova-review, nova-spec-workflow |
| Nova Core Security | [`nova-coresec.md`](agents/nova-coresec.md) | nova-review, nova-bug-triage, nova-spec-workflow |
| OpenStack Bug Triager | [`bug-triager.md`](agents/bug-triager.md) | nova-bug-triage |
| Backport Specialist | [`backport-specialist.md`](agents/backport-specialist.md) | gerrit-to-gitlab |
| OpenStack Operator | [`openstack-operator.md`](agents/openstack-operator.md) | nova-bug-triage |

See [`agents/README.md`](agents/README.md) for details on how personas work, when to use them, and how to create new ones.

## Repository Structure

```text
agents/
├── nova-core.md           # Nova core reviewer persona
├── nova-coresec.md        # Nova security reviewer persona
├── bug-triager.md         # Bug triage specialist persona
├── backport-specialist.md # Backport specialist persona
├── openstack-operator.md  # Operator perspective persona
└── README.md              # Persona documentation
knowledge/
└── nova.md                # Shared Nova project reference (used by Nova workflows)
workflows/
├── nova-review/           # Nova code and spec review
│   ├── .ambient/
│   │   └── ambient.json   # Workflow config (name, description, prompts)
│   ├── .claude/
│   │   └── skills/        # Review skills (spec-review, code-review, gerrit-comment)
│   ├── AGENTS.md          # Nova project reference (model-agnostic)
│   ├── CLAUDE.md          # Pointer to AGENTS.md
│   ├── rules.md           # Behavioral rules for the agent
│   └── README.md
├── nova-bug-triage/       # Nova Launchpad bug triage
│   ├── .ambient/
│   │   └── ambient.json
│   ├── .claude/
│   │   └── skills/        # Triage skills (triage, reproduce, report, update-launchpad)
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   ├── rules.md
│   └── README.md
├── gerrit-to-gitlab/      # Gerrit-to-GitLab backport workflow
│   ├── .ambient/
│   │   └── ambient.json
│   ├── .claude/
│   │   └── skills/        # Backport skills (backport, test, create-mr)
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   ├── rules.md
│   └── README.md
├── nova-spec-workflow/    # Nova spec authoring from JIRA RFEs or descriptions
│   ├── .ambient/
│   │   └── ambient.json
│   ├── .claude/
│   │   └── skills/        # Spec skills (create-spec, refine-spec, blueprint)
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   ├── rules.md
│   └── README.md
└── [future-workflows]/    # Workflows for other OpenStack services
```

### Workflow Requirements

Every workflow must have:

- `.ambient/ambient.json` with `name`, `description`, `systemPrompt`, and `startupPrompt`
- A `README.md` documenting its purpose and usage

## Design Principles

- **Do not duplicate deterministic checks.** If a linter or CI job already enforces a rule, the workflow should not re-check it.
- **Use in-tree docs as the source of truth.** Reference each project's contributor documentation rather than forking rules into the workflow.
- **Model-agnostic where possible.** Project knowledge goes in `AGENTS.md` (usable by any AI tool); `CLAUDE.md` is a thin pointer for Claude-specific tooling.
- **Human decides, agent assists.** Workflows provide analysis and draft comments, but the human makes final decisions (e.g., Gerrit votes).

## Contributing

1. Fork this repository
2. Create a new workflow directory under `workflows/`
3. Add `.ambient/ambient.json` with the required fields
4. Test using the "Custom Workflow" feature in ACP
5. Submit a pull request
