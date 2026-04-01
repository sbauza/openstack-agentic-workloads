# Nova Spec Author

Generate well-structured nova-spec proposals from JIRA RFE tickets or free-form feature descriptions. Includes interactive clarification, architectural review via Nova core reviewer personas, and Launchpad blueprint registration.

## Skills

| Skill | Description |
|-------|-------------|
| `/create-spec` | Generate a nova-spec from a JIRA RFE or feature description |
| `/refine-spec` | Review and refine a generated spec with architectural feedback |
| `/blueprint` | Add Launchpad blueprint URL to a spec |

## Prerequisites

- **Required**: ACP (Ambient Code Platform) session
- **Recommended**: `openstack/nova-specs` repository added to the workspace (for template and release detection)
- **Optional**: JIRA MCP integration configured (for automatic RFE ticket extraction; manual paste fallback available)

## Usage

### Load the Workflow

1. In ACP, select **"Custom Workflow..."**
2. Fill in the fields:
   - **URL**: `https://github.com/sbauza/openstack-agentic-workflows.git`
   - **Branch**: `main`
   - **Path**: `workflows/nova-spec-workflow`
3. Click **"Load Workflow"**

### Create a Spec from a JIRA RFE

```text
/create-spec NOVA-1234
```

The workflow reads the JIRA ticket, asks you 3 clarification questions about the problem, use cases, and approach, then generates a complete nova-spec RST file.

### Create a Spec from a Description

```text
/create-spec Add support for live migration of instances with vGPUs
```

### Refine a Generated Spec

```text
/refine-spec
```

Checks structural completeness, invokes `nova-core` and `nova-coresec` agents for architectural review, and helps strengthen weak sections interactively.

### Add Blueprint URL

```text
/blueprint vgpu-live-migration
```

## Output

Generated specs are written to `artifacts/nova-spec-workflow/`. RST files are ready to be copied into the `nova-specs` repository for Gerrit submission.

## Agent Personas

This workflow reuses shared agent personas from the repository root:

- **nova-core** — Architectural fit, versioning, conductor boundary, upgrade safety
- **nova-coresec** — Security review for privsep, RBAC, credential handling
