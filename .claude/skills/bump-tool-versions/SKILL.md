---
name: bump-tool-versions
description: Bump pinned tool versions (Mise runtime, Terraform) across .mise.toml, GitHub workflows, and Terraform module version constraints
user-invocable: true
model: Sonnet
allowed-tools: Read, Edit, Grep, Glob, WebFetch, Agent, Bash(mise:*), Bash(*/mise:*), Bash(mise exec -- uv run pre-commit run:*), Bash(*/mise exec -- uv run pre-commit run:*)
---

# Bump Pinned Tool Versions

## Purpose

Update the pinned versions of **Mise** (runtime) and **Terraform** everywhere they are
referenced, in lockstep, so the repo stays internally consistent.

Use this skill when the user asks to "bump mise", "update terraform to 1.X", "upgrade the
mise version in CI", or similar.

## Arguments

The skill accepts an optional tool selector as its first argument. Recognised values:

| Argument          | Behavior                                                                  |
| ----------------- | ------------------------------------------------------------------------- |
| `mise`            | Run only the Mise flow (Section A).                                       |
| `terraform`       | Run only the Terraform flow (Section B).                                  |
| `all` (or empty)  | Run **every** flow this skill knows about, in order (currently A then B). |

Tool selectors are case-insensitive. If the input does not start with a recognised
selector, treat it as free-form guidance and default to `all`.

If the user passes additional free-form text after (or instead of) the tool selector
(e.g. "set hard to 2025.1.0", "soft only"), treat it as extra guidance to apply within
the selected flow(s) — but never let it skip the standard procedure (release-notes
review, lint, report).

Parsing rule (automation-first):

- If the first token is one of `mise|terraform|all`, use it as the selector.
- Otherwise, default selector to `all` and treat the full user text as guidance.
- Ask a clarifying question only when guidance is internally contradictory (for example,
  both "soft only" and "hard only" are present).

When new tool flows are added to this skill, also add them to the table above and to the
`all` iteration order so the default invocation stays complete.

## Scope

This skill covers two independent upgrades. The `Arguments` section above determines which
flow(s) to run on a given invocation; the default (no argument) is to run every flow.

### A. Mise runtime version

The Mise **runtime** itself (not the tools it manages). Pin locations:

| File                          | Field                                                  |
| ----------------------------- | ------------------------------------------------------ |
| `.mise.toml`                  | `min_version = { hard = "<HARD>", soft = "<SOFT>" }`   |
| `.github/workflows/lint.yml`  | `jdx/mise-action@v4` step → `with: version: <SOFT>`    |

**Semantics:**

- `hard` — absolute floor; older `mise` binaries refuse to load the config.
- `soft` — recommended version; `mise` warns if below. Keep `hard ≤ soft`.
- The `lint.yml` workflow pins the exact version installed in CI — keep it in sync with
  `soft` so CI runs on the recommended version.

### B. Terraform version

Terraform is pinned in two kinds of places: the `mise` tool spec (using the `prefix:`
resolver for the binary to install) and each Terraform module's `required_version`
constraint (enforced by `terraform` at plan/apply time).

| File                                           | Field / Pattern                                |
| ---------------------------------------------- | ---------------------------------------------- |
| `.mise.toml`                                   | `terraform = "prefix:<MAJOR.MINOR>"`           |
| `src/terraform/versions.tf`                    | `required_version = ">= <MAJOR.MINOR>"`        |
| `src/terraform/bootstrap/main.tf`              | `required_version = ">= <MAJOR.MINOR>"`        |
| `src/terraform/modules/*/main.tf`              | `required_version = ">= <MAJOR.MINOR>"`        |

Before editing, run this to confirm the full current list (new modules may have been added):

Use Grep with pattern `required_version\s*=` and glob `src/terraform/**/*.tf` to list
every file containing a `required_version` directive.

## Procedure

### Step 1 — Determine target versions

Do **not** ask the user for an exact target version. Derive the recommended target
from the release-notes analysis in Step 2 — run Step 2 first, then apply the rules
below.

If the user's original request specified an exact target (e.g. "bump terraform to 1.15"),
take their value verbatim and skip derivation. Otherwise apply these defaults:

- **Mise**:
  - `soft`: newest stable version found in the release notes (calendar-style, e.g.
    `2026.4.17` — see [mise releases](https://github.com/jdx/mise/releases)).
  - `hard`: conservative floor derived from Step 2:
    - raise to the first release that includes a relevant security fix (CVE/advisory), or
    - if none, raise to the first release with a bug fix affecting repo-used code paths, or
    - if neither applies, keep current `hard` unchanged.
  - Keep `hard ≤ soft`.
  - User override rules:
    - "soft only" → update only `soft` (still report if this leaves known security/bug risk)
    - "hard only" → update only `hard`
    - explicit pair (e.g. "hard to X, soft to Y") → use their values
- **Terraform**: target the newest **stable** `MAJOR.MINOR` (e.g. `1.15`). Skip release
  candidates, betas, and just-cut GAs with no follow-up patch yet — wait for at least
  one patch release (`.1`) before bumping. The `prefix:` resolver picks the newest
  matching patch automatically.

If Step 2 concludes no suitable stable target exists (e.g. only prereleases are newer
than the current pin), report that back to the user and stop — do not bump.

### Step 2 — Review release notes (delegate to a sub-agent)

Before editing anything, summarise the release notes between the current pinned version
(exclusive) and the target version (inclusive). This is what informs the `hard` floor
decision and the recommendation you give back to the user.

**Delegate the fetch and summarisation to an available read-only sub-agent** (via the
`Agent` tool) rather than calling `WebFetch` directly. Raw release pages are 5–50 KB each — a
year-long Mise gap can pull 50–500 KB into context. The sub-agent reads the raw pages and
returns only a compact structured summary; the raw pages never enter the parent context.

**Sources** to point the sub-agent at:

- **Mise**: `https://github.com/jdx/mise/releases`, or per-tag
  `https://github.com/jdx/mise/releases/tag/v{VERSION}`
- **Terraform**: `https://github.com/hashicorp/terraform/releases`, or the canonical
  changelog `https://raw.githubusercontent.com/hashicorp/terraform/v{VERSION}/CHANGELOG.md`

The sub-agent prompt MUST:

- Name the tool, current pinned version, and target version
- Include the canonical source URL(s) above
- Ask for one section per category, in this exact order:
  1. **Security / CVE fixes in the tool itself** (cite advisory IDs and first fixed version)
  2. **Bug fixes affecting repo-used code paths**: summarize impact on this repo.
     - For Mise: `prefix:` resolver, `[tools]` parsing, `min_version` handling,
       `jdx/mise-action` GitHub Action handshake
     - For Terraform: S3 backend, AWS provider invocation, `required_version`
       enforcement, `.terraform.lock.hcl` format
  3. **Breaking changes and deprecations** (include removal version if stated)
  4. **New features this repo could adopt**: include only practical options.
- Cap the response: **"under 400 words"**
- Return "none" for any empty section rather than omitting it

If the returned summary lacks detail needed for a `hard`-floor decision (e.g. a CVE
mentioned with no patched-version), follow up in-conversation with a single targeted
`WebFetch` on that specific release tag — do not re-fetch the whole range.

#### Deciding the `hard` floor (Mise only)

`hard` must be conservative and justified.

Use this decision order:

1. If security/CVE fixes in `mise` affect versions above current `hard`, set `hard` to
   the **first fixed release** that addresses the relevant advisory.
2. Else, if repo-impacting bug fixes affect versions above current `hard`, set `hard`
   to the **first release** containing the relevant bug fix.
3. Else, keep current `hard` unchanged.

Always keep `hard ≤ soft`.

In the report, explicitly cite the trigger used for the decision (CVE/advisory ID or
specific bug/fix), or state that no qualifying fixes were found.

#### Deciding the Terraform `required_version` operator

Default: keep `>=` and just swap the `MAJOR.MINOR`. Only propose tightening (e.g. to `~>`)
if the release notes document a breaking change this repo actually depends on.

### Step 3 — Locate all pin sites

Before editing, grep the repo to confirm the set of files matches the table above. New
modules under `src/terraform/modules/` must also be updated.

- Grep `required_version\s*=` in `src/terraform/**/*.tf`
- Grep `min_version` in `.mise.toml`
- Grep `mise-action` in `.github/workflows/*.yml`

If pins exist outside these locations, surface them to the user — do not silently skip.

### Step 4 — Edit files

Use the Edit tool with tight `old_string` context so the match is unambiguous. Update
every file found in Step 3. Do not reformat surrounding lines.

### Step 5 — Regenerate Terraform lock files (Terraform bumps only)

Changing the Terraform minor version can invalidate provider lock files. After editing,
have the user run (or run via the `terraform` skill):

```bash
make terraform-lock
```

This regenerates `.terraform.lock.hcl` for both the root module and `bootstrap/` for
`darwin_arm64` and `linux_amd64`.

### Step 6 — Run lint on the changed files

```bash
mise exec -- uv run pre-commit run --files <changed files>
```

Fix any reported issues before reporting the task complete. Do not bypass hooks.

### Step 7 — Report with recommendations

Produce a short report that combines **what changed** with the **release-notes summary**
from Step 2. Use this shape:

```markdown
## <Tool> <old> → <new>

**Breaking changes in this range**
- <bullet — or "none">

**Decisions made**
- `hard` floor: <unchanged | raised to X because …>  (Mise only)
- `required_version` operator: <unchanged | tightened because …>  (Terraform only)

**Recommendations to consider separately**
- <e.g. "adopt new feature X to replace workaround Y in file Z">
- <e.g. "deprecation warning for config key K — plan removal before version N">
- <bullet — or "none">

**Files touched**
- <path>
- …

**Next step for you**: <run `make terraform-lock` / commit as `ci(mise): bump mise to X`>
```

The "Recommendations" block is the most important output — it is what the user uses to
decide follow-up work. Do **not** silently implement those recommendations in the same
change; list them so the user can schedule them. Remind the user to commit `.mise.toml`,
the workflow, the `.tf` files, and any regenerated `.terraform.lock.hcl` files in a
single `chore(deps):` or `ci(mise):` / `ci(terraform):` commit per Conventional Commits.

## Guardrails

- **Do not bump `hard` above `soft`.** Always keep `hard ≤ soft` in `.mise.toml`.
- **Do not change `required_version` operators** (`>=`, `~>`) unless the user asks — only
  swap the version number.
- **Do not touch unrelated tool pins** in `.mise.toml` (`pre-commit`, `tflint`, `uv`) unless
  the user asks.
- **Do not commit.** Per repo policy, only commit/push when explicitly asked.
