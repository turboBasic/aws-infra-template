# AI Instructions - GitHub Copilot

This repository keeps AI coding instructions in a single source of truth:

- [docs/ai-instructions.md](../docs/ai-instructions.md)

GitHub Copilot: follow the linked instructions as if they were in this file.

Shared skills are defined in `.claude/skills/`. Use those skills and avoid creating duplicated skill instructions under `.github/skills/`.

## Command execution permissions

When evaluating or executing shell commands, GitHub Copilot should follow the shared
auto-approve policy defined in [docs/ai-instructions.md](../docs/ai-instructions.md).
Use these sources in this order:

1. VS Code settings (workspace/user) allow/deny command rules
2. `.claude/settings.json` (base rules)
3. `.claude/settings.local.json` (local overrides, if present)

If VS Code settings define allowed/denied command rules, GitHub Copilot must use those
rules first; they override the shared policy from `.claude/settings*.json`.

- Auto-approve only commands that match `permissions.allow`.
- Never execute commands that match `permissions.deny`.
- If a command is not explicitly allowed, request user confirmation before execution.
