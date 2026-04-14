---
name: nova-blueprint
description: Generate and insert a Launchpad blueprint URL at the top of a nova-spec file. Use after finalizing a spec to register the Launchpad blueprint.
---

# Blueprint

Generate the Launchpad blueprint URL for a nova-spec and insert it at the top of the RST file. Every nova-spec must reference its corresponding Launchpad blueprint as the first item in the file.

## Input

The user will provide one of:

- A spec name (e.g., `vgpu-live-migration`)
- A path to a spec file (e.g., `artifacts/nova-spec-workflow/vgpu-live-migration.rst`)
- No argument — uses the most recently generated spec in `artifacts/nova-spec-workflow/`

## Process

### 1. Determine Spec Name and File

- If a path is provided: extract the spec name from the filename (strip `.rst` extension)
- If a name is provided: look for the corresponding file in `artifacts/nova-spec-workflow/{name}.rst`
- If no argument: find the most recently modified `.rst` file in `artifacts/nova-spec-workflow/`
- If no spec files exist: "No spec found. Run `/nova-create-spec` first to generate a draft."

### 2. Generate Blueprint URL

Construct the URL using the standard Launchpad format:

```
https://blueprints.launchpad.net/nova/+spec/{spec-name}
```

### 3. Check for Existing Blueprint URL

Read the spec file and check if a blueprint URL is already present at the top:

- Look for a line matching `https://blueprints.launchpad.net/nova/+spec/`
- If found: verify the URL matches the expected format and spec name
  - If correct: "Blueprint URL already present and correctly formatted. No changes needed."
  - If incorrect (wrong spec name): report the mismatch and offer to fix it
- If not found: proceed to insertion

### 4. Insert Blueprint URL

Insert the blueprint URL at the very top of the RST file, before the spec title:

```rst
..
    https://blueprints.launchpad.net/nova/+spec/{spec-name}

============================
{Spec Title}
============================
```

### 5. Write Updated Spec

Write the updated RST file back to the same path.

Report:

```
## Blueprint Added

**URL**: https://blueprints.launchpad.net/nova/+spec/{spec-name}
**File**: {path}

Remember to create the actual blueprint on Launchpad before submitting the spec to Gerrit:
https://blueprints.launchpad.net/nova/+addspec
```

## Output

- **Artifact**: Updated RST file with blueprint URL inserted at the top
- **Session output**: Blueprint URL and confirmation

## Error Conditions

| Condition | Behavior |
|-----------|----------|
| No spec found | Instruct contributor to run `/nova-create-spec` first |
| Blueprint URL already present | Verify format, skip insertion, report status |
| Invalid spec name (contains invalid characters) | Report error, suggest valid naming (lowercase, hyphens, no special chars) |

### Writing Style

Follow the rules in `rules.md`.
