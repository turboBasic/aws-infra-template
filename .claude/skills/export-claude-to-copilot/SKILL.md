---
name: export-claude-to-copilot
description: Reproduce Claude Code allowed commands and web tools in native GitHub Copilot workspace settings for this project
user-invocable: true
model: Haiku
allowed-tools: Bash(rg:*), Bash(*/rg:*), Bash(mise:*), Bash(*/mise:*), Bash(terraform:*), Bash(*/terraform:*), Bash(gh pr:*), Bash(*/check-aws-auth.sh), Bash(*/setup-aws-auth.sh)
---

# Export Claude Permissions To Copilot

## Purpose

Keep native VS Code and GitHub Copilot settings in sync with the shared Claude permission policy for this repository.

This skill converts Claude allow rules from `.claude/settings.json` (plus optional `.claude/settings.local.json` override) into native Copilot settings in `.vscode/settings.json`.

## When To Use

Use this skill when:

- `.claude/settings.json` changes
- `.claude/settings.local.json` changes
- You need Copilot command/tool approvals to match Claude behavior
- The project is cloned on a new machine and workspace settings must be initialized

## Source Of Truth And Precedence

Compute the effective Claude policy by taking the **union** of allow rules from:

1. `.claude/settings.json` base rules
2. `.claude/settings.local.json` local rules (if present)

Allow rules from both files are combined, not replaced. Duplicates collapse to a single entry. An empty `allow: []` in the local file contributes nothing and does **not** hide base rules.

Deny rules, if present at either level, override matching allow rules — a tool denied at any level cannot be auto-approved. See the [Claude Code permissions docs](https://code.claude.com/docs/en/permissions.md#settings-precedence) for the authoritative behavior.

## Native Copilot Settings Used

Write rules to `.vscode/settings.json` using the keys listed in [Managed Keys](#managed-keys).

## Mapping Rules

### Terminal Commands

Claude patterns like `Bash(...)` map to `chat.tools.terminal.autoApprove` entries.

Recommended conversions for this repository:

- `Bash(gh pr *)` -> `"gh pr": true`
- `Bash(terraform fmt:*)` -> `"/(^|\\s)(?:[^\\s]+\/)?terraform\\s+fmt\\b/": true`
- `Bash(terraform version:*)` -> `"/(^|\\s)(?:[^\\s]+\/)?terraform\\s+version\\b/": true`
- `Bash(*/terraform fmt:*)` -> same regex as above
- `Bash(*/terraform version)` -> same regex as above
- `Bash(*/check-aws-auth.sh)` -> `"/(^|\\s)(?:[^\\s]+\/)?check-aws-auth\\.sh\\b/": true`
- `Bash(*/setup-aws-auth.sh)` -> `"/(^|\\s)(?:[^\\s]+\/)?setup-aws-auth\\.sh\\b/": true`
- `Bash(*/mise:*)` and `Bash(mise:*)` -> `"mise": true` and `"/(^|\\s)(?:[^\\s]+\/)?mise\\b/": true`

### Web Tools

- `WebFetch(domain:registry.terraform.io)` -> `chat.tools.urls.autoApprove` entry `"https://registry.terraform.io/*": true`
- `WebSearch` has no strict per-domain command equivalent; keep global auto-approve disabled and allow normal approval flow unless project policy explicitly opts into broader auto-approval.

## Required Baseline

Always keep these settings:

- `"chat.tools.global.autoApprove": false`
- `"chat.tools.terminal.enableAutoApprove": true`
- `"chat.tools.terminal.ignoreDefaultAutoApproveRules": true`

Rationale:

- Prevent accidental blanket approvals
- Ignore VS Code default terminal auto-approve rules so only project-defined rules apply

## Guardrails Against Blanket Auto-Approval

**Never** write rules that would auto-approve broad or unbounded command sets. Refuse to produce the following patterns, even if the source Claude policy appears to allow them:

| Forbidden pattern | Why |
| --- | --- |
| `"*": true` in `chat.tools.terminal.autoApprove` | Approves every terminal command |
| `"/(.*)/": true` or `"/.*/"` in terminal auto-approve | Regex that matches anything |
| `"chat.tools.global.autoApprove": true` | Disables all approval prompts globally |
| `"https://*/*": true` or `"*": true` in `chat.tools.urls.autoApprove` | Approves fetches to any URL |
| `"chat.agent.allowedNetworkDomains": ["*"]` | Opens unrestricted outbound network access |

If the effective Claude policy contains a rule that would require one of these patterns to faithfully represent it, **do not write the blanket rule**. Instead:

1. Skip the rule.
2. Add a comment in `.vscode/settings.json` noting the skipped rule and why (e.g., `// skipped: Bash(*) — too broad for Copilot auto-approve`).
3. Include the skipped rule in the summary with an explanation.

## Managed Keys

The skill exclusively owns these `.vscode/settings.json` keys — do not touch any other key:

- `chat.tools.global.autoApprove`
- `chat.tools.terminal.enableAutoApprove`
- `chat.tools.terminal.ignoreDefaultAutoApproveRules`
- `chat.tools.terminal.autoApprove`
- `chat.tools.urls.autoApprove`
- `chat.agent.networkFilter` *(optional — only present when needed)*
- `chat.agent.allowedNetworkDomains` *(optional)*
- `chat.agent.deniedNetworkDomains` *(optional)*

## Update Procedure

1. Read `.claude/settings.json` and `.claude/settings.local.json`.
2. Compute effective allow list.
3. Translate allow items using mapping rules above.
4. Update `.vscode/settings.json` in-place, modifying only [Managed Keys](#managed-keys).
5. Remove stale entries inside managed keys that are no longer in effective policy.
6. Note any Claude allow entries with no Copilot equivalent (e.g., `WebSearch`) in the summary.
7. Summarize what changed and why. VS Code validates JSONC syntax on open — no separate validation step is needed.

## Safe Defaults

If effective allow list is empty:

- Set `chat.tools.terminal.autoApprove` to `{}`
- Set `chat.tools.urls.autoApprove` to `{}`
- Optionally set network filter to restrictive mode:
  - `"chat.agent.networkFilter": true`
  - `"chat.agent.allowedNetworkDomains": []`
  - `"chat.agent.deniedNetworkDomains": []`

## Notes

- Keep this skill in `.claude/skills/` only; do not duplicate under `.github/skills/`.
- Keep changes minimal and scoped to workspace settings.
- Do not edit global user settings when applying this project policy.
