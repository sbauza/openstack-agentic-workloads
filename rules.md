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

## Filesystem Boundaries

Workflows operate within a restricted set of directories. Agents must **never** read or write files outside these paths:

- `/workspace/repos/` — source code repositories added to the session
- The workflow's own directory tree (skills, rules, artifacts)
- `/tmp/` — temporary files only

Specifically, agents must **not**:

- Access the user's home directory, SSH keys, credentials, or dotfiles
- Read or modify system files outside `/workspace/`
- Execute commands that write outside the allowed paths

If a workflow needs shell access (e.g., `git` operations for backporting), the main workflow agent may use `Bash` — but only for commands scoped to `/workspace/repos/` and the workflow's artifact directory. **Subagent personas must never have `Bash` access** — they are read-only analysts.

## Human-Readable Comments

All review comments — whether in artifacts, Gerrit, or conversation — must be written for human consumption:

- Write in plain, direct language — no jargon walls or template-speak
- Each comment should be self-contained: a reader should understand the issue without cross-referencing other comments
- Lead with **what's wrong and why it matters**, then suggest a fix
- Keep inline comments short — one issue, one actionable sentence or two
- Avoid dumping raw rule references alone; explain what the rule means in context
- Use a conversational, respectful tone — write as a helpful colleague, not an automated linter
