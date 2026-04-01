# Rules

These rules apply to **all workflows** in this repository.

## Human Always Decides

The agent provides analysis, suggestions, and draft outputs. The **human makes all final decisions**. This includes:

- **Gerrit votes**: Never suggest or auto-select a Code-Review score. Ask the user what vote they want to apply.
- **Posting comments**: Never post to Gerrit, Launchpad, or any external service without explicit user approval.
- **Merge/abandon actions**: Never take actions that change the state of a change, bug, or spec without the user confirming.

When presenting options, lay out the choices clearly and let the user decide. Do not assume what they would choose.

## Self-Review Before Presenting

Before presenting any output to the user:

1. Re-read your output as if you are a code reviewer
2. Check for:
   - Missing edge cases
   - Security issues (injection, validation, secrets)
   - Incomplete reasoning
   - Assumptions that should be stated
3. Autocorrect your response
4. Only then present to the user

If you found and fixed issues, briefly note: "Self-review: Fixed [issue]"

## Nova Project Knowledge Required

All workflows in this repository operate on OpenStack Nova. Every workflow **must** reference `knowledge/nova.md` so the agent has access to Nova's architecture, versioning rules, coding conventions, and service topology. This applies regardless of the workflow's primary purpose — even backporting workflows need Nova context to resolve conflicts correctly.

When creating or modifying a workflow, ensure `knowledge/nova.md` is loaded:

- **AGENTS.md**: include `@../../knowledge/nova.md`
- **CLAUDE.md**: inherited transitively via `@AGENTS.md`
- **Cursor `.mdc` rules**: must include `@../knowledge/nova.md` via the workflow's `knowledge` symlink (Cursor does not follow nested `@` references)

A workflow without Nova project knowledge cannot correctly assess versioning rules, conductor boundaries, or architectural fit.

## Human-Readable Comments

All review comments — whether in artifacts, Gerrit, or conversation — must be written for human consumption:

- Write in plain, direct language — no jargon walls or template-speak
- Each comment should be self-contained: a reader should understand the issue without cross-referencing other comments
- Lead with **what's wrong and why it matters**, then suggest a fix
- Keep inline comments short — one issue, one actionable sentence or two
- Avoid dumping raw rule references alone; explain what the rule means in context
- Use a conversational, respectful tone — write as a helpful colleague, not an automated linter
