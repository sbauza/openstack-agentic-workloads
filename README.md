# OpenStack Agentic Workloads

Custom workflow repository for OpenStack services, primarily consumed by the [Ambient Code Platform](https://ambient.code) (ACP).

## Overview

This repository contains ACP workflow definitions tailored for OpenStack development. Each workflow provides structured processes — skills, rules, and project-specific knowledge — that guide AI agents through complex OpenStack tasks like code review, spec review, and Gerrit interaction.

The platform automatically discovers workflows from this repository. Any directory under `workflows/` with a valid `.ambient/ambient.json` file appears in the ACP UI.

## Available Workflows

| Workflow | Description | Skills |
|----------|-------------|--------|
| [**nova-review**](workflows/nova-review/) | Review Nova code changes and nova-specs proposals against project conventions and architecture | `/spec-review`, `/code-review`, `/gerrit-comment` |

## Using Workflows

### In the ACP UI

1. Navigate to your session
2. Open the **Workflows** panel
3. Select a workflow from the list
4. The workflow loads and displays its startup prompt

### Custom Workflows

To test a workflow from a branch or external repository:

1. Select **"Custom Workflow..."** in the UI
2. Enter the Git URL, branch, and path to the workflow directory
3. Click **"Load Workflow"**

## Repository Structure

```text
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
