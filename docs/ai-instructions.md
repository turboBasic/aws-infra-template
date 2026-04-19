<!-- pyml disable md025 -->
# AI Instructions

> **Single source of truth for AI coding instructions.**
>
> - **Claude Code** reads this via `CLAUDE.md` (`@docs/ai-instructions.md`).
> - **GitHub Copilot** reads `.github/copilot-instructions.md`, which links to this file.
> - **Edit only this file.** CI verifies Copilot instructions reference it.

---

# AWS Infrastructure Template

Polyglot project template. Terraform code lives under `src/terraform/`; the repo
root is reserved for language-agnostic tooling (CI, linters, editor config, AI
instructions, docs).

## Architecture

Two-stage Terraform deployment, both under `src/terraform/`:

1. **`src/terraform/bootstrap/`** (persistent, apply once) — S3 state-backend
   bucket, S3 state-backup bucket, DynamoDB lock table. Uses the local backend
   for its own state.
2. **`src/terraform/`** (root module, applied repeatedly) — wires the provider
   and calls the child modules below. Uses the S3 backend created by bootstrap
   (after swapping `backend "local" {}` for an `backend "s3" {}` block in
   [../src/terraform/backend.tf](../src/terraform/backend.tf)).

Root-module child modules:

- **`modules/networking/`** — VPC with public and private subnets.
- **`modules/storage/`** — a single S3 bucket with public-access block, TLS-only policy,
  and default encryption.

## Tech Stack

| Tool             | Version / Notes                                                   |
| ---------------- | ----------------------------------------------------------------- |
| Primary language | Terraform (HCL)                                                   |
| Task runner      | `make` (see [Makefile](../Makefile))                              |
| Python toolchain | [`uv`](https://docs.astral.sh/uv/) — dev deps in `pyproject.toml` |
| Tool versioning  | [`mise`](https://mise.jdx.dev) — pins `terraform`, `uv`, etc.     |
| CI               | GitHub Actions                                                    |

## Workflow

### Deploy bootstrap resources (first time only)

See [@src/terraform/bootstrap/README.md](../src/terraform/bootstrap/README.md) for the full guide.
TL;DR:

```bash
cd src/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # edit values
mise exec -- terraform init
mise exec -- terraform apply

# Back up the local bootstrap state to the backup bucket
mise exec -- terraform output -json bootstrap_state_backup_commands | jq -r '.upload' | bash
```

Then edit [../src/terraform/backend.tf](../src/terraform/backend.tf), replacing
the `backend "local" {}` stub with the `backend "s3" {...}` block printed by
`terraform output -json backend_config`.

### Deploy resources from the root Terraform module

```bash
cd src/terraform
mise exec -- terraform init -migrate-state   # first time after backend swap
mise exec -- terraform apply
```

To tear everything down:

```bash
cd src/terraform
mise exec -- terraform destroy
```

## Make targets

The [Makefile](../Makefile) wraps the most common dev tasks. All targets execute through
`mise exec -- uv` so they use the mise-pinned `uv` and the uv-managed virtualenv.

```bash
make help        # list all targets
make install     # uv sync --frozen  — install dev deps from uv.lock
make lock        # uv lock           — regenerate uv.lock after editing pyproject.toml
make lint        # uv run pre-commit run --all-files
```

Typical bootstrap in a fresh clone:

```bash
make lock               # generate uv.lock from pyproject.toml (first time only)
make install            # creates .venv and installs pre-commit
mise exec -- uv run pre-commit install   # enable git hooks
```

After editing `pyproject.toml` (adding/removing/bumping a Python dev dep):

```bash
make lock && make install   # regenerate uv.lock and re-sync .venv
```

`make install` uses `--frozen`, so it will fail fast if `uv.lock` is missing or
out of sync with `pyproject.toml` — this is intentional and enforces reproducible installs.

## AWS Authentication

**IMPORTANT**: Always use the `aws` skill to configure authentication before running AWS CLI commands or Terraform operations.

Set `AWS_PROFILE` to the profile you want the project to use:

```bash
export AWS_PROFILE=<your-profile>
aws sts get-caller-identity
```

See [@.claude/skills/aws/SKILL.md](.claude/skills/aws/SKILL.md) for complete authentication documentation including setup helpers, error handling, and alternative methods.

## Terraform Executable Location

**IMPORTANT**: Before running any Terraform commands, always use the terraform skill. The repo pins terraform via [.mise.toml](../.mise.toml); the skill runs that pinned version through Homebrew-installed [mise](https://mise.jdx.dev).

Quick start:

```bash
cd src/terraform
mise exec -- terraform init
mise exec -- terraform plan
mise exec -- terraform apply
```

See [@.claude/skills/terraform/SKILL.md](.claude/skills/terraform/SKILL.md) for details and error handling.

## Terraform Commands

```bash
terraform init          # Initialize providers and modules
terraform fmt           # Format all .tf files
terraform fmt -check    # Check formatting without modifying
terraform validate      # Validate configuration syntax
terraform plan          # Preview changes
terraform apply         # Apply changes (requires confirmation)
terraform destroy       # Tear down all resources (requires confirmation)
```

## Project Structure

```text
aws-infra-template/
├── Makefile                         # Dev task runner (install, lock, lint)
├── pyproject.toml                   # Python dev dependency manifest (uv)
├── uv.lock                          # uv lockfile — committed for reproducibility
├── .mise.toml                       # Pinned tool versions (terraform, uv, …)
├── .pre-commit-config.yaml          # Pre-commit hook definitions
├── README.md                        # Project documentation
├── CLAUDE.md                        # Claude Code instructions
├── docs/
│   └── ai-instructions.md           # AI coding instructions (source of truth)
├── scripts/
│   └── terraform-validate-module.sh # Pre-commit helper: validate one Terraform module
└── src/
    └── terraform/
        ├── main.tf                      # Root module: provider wiring + module calls
        ├── versions.tf                  # Terraform version and provider requirements
        ├── providers.tf                 # Provider configurations (aws)
        ├── variables.tf                 # Root variables
        ├── outputs.tf                   # Root outputs
        ├── backend.tf                   # Backend configuration (local by default; swap to s3 after bootstrap)
        ├── locals.tf                    # name_prefix, common_tags
        ├── data.tf                      # caller_identity, region
        ├── terraform.tfvars.example     # Example variable values
        ├── bootstrap/
        │   ├── main.tf                  # Provider config (local backend)
        │   ├── variables.tf             # region, project_name, environment, state_key
        │   ├── outputs.tf               # bucket, table, backend_config, backup commands
        │   ├── locals.tf                # name_prefix, tags
        │   ├── state.tf                 # S3 state bucket + DynamoDB lock table
        │   ├── bootstrap-state-bucket.tf# S3 bucket for bootstrap state backup
        │   ├── terraform.tfvars.example # Example variable values
        │   └── README.md                # Bootstrap deployment instructions
        └── modules/
            ├── networking/              # VPC, subnets, IGW, route tables
            └── storage/                 # S3 bucket with TLS-only policy and encryption
```

## Code Style & Conventions

### Commit messages

Use Conventional Commits format: `type(scope): subject` — imperative mood, no trailing period.
Example: `fix(ci): handle missing env variable`

The allowed list of `type`s lives in [`.commitlintrc.json`](../.commitlintrc.json) and is
the single source of truth shared by:

- the local `commitlint` pre-commit hook (runs on `commit-msg` stage — see
  [Pre-commit](#pre-commit) for install)
- the [`vivaxy.vscode-conventional-commits`](https://marketplace.visualstudio.com/items?itemName=vivaxy.vscode-conventional-commits)
  VS Code extension (reads `type-enum` directly from the commitlint config)
- the [`wagoid/commitlint-github-action`](https://github.com/wagoid/commitlint-github-action)
  job that validates commit messages on pull requests
- the [`amannn/action-semantic-pull-request`](https://github.com/amannn/action-semantic-pull-request)
  job that validates PR titles (the workflow extracts the list from
  `.commitlintrc.json` via `jq` and passes it to the action)

To add or remove a type, edit `rules.type-enum` in `.commitlintrc.json` only —
all four consumers pick up the change automatically.

### Terraform

- **Variable naming**: snake_case, descriptive names with `description` and `type` always set
- **File organization**: group related resources into dedicated modules under `src/terraform/modules/`; within a module use focused files (`main.tf`, `variables.tf`, `outputs.tf`, `README.md`)
- **Formatting**: always run `terraform fmt` before finishing any change to `.tf` files
- **Lock files**: when provider versions change, update lock files for both macOS and Linux, then commit both lock files in the same PR:

   ```bash
   make terraform-lock
   ```

   Equivalent manual commands:

   ```bash
   cd src/terraform
   mise exec -- terraform providers lock -platform=darwin_arm64 -platform=linux_amd64

   cd bootstrap
   mise exec -- terraform providers lock -platform=darwin_arm64 -platform=linux_amd64
   ```

- **Tagging**: tag all resources via `common_tags` from `src/terraform/locals.tf` (root) or `src/terraform/bootstrap/locals.tf` (bootstrap)
- **Security groups**: use standalone `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` resources (provider 6.x best practice — avoids rule conflicts)

### Pre-commit

The project uses [pre-commit](https://pre-commit.com) to enforce formatting and linting.
`pre-commit` itself is installed as a Python dev dependency via `uv` — see the
[Make targets](#make-targets) section for the install flow. Configured hooks:

| Hook                           | Scope                                                                |
| ------------------------------ | -------------------------------------------------------------------- |
| `terraform_fmt`                | All `.tf` and `.tfvars` files                                        |
| `terraform_tflint`             | Terraform lint checks on changed Terraform directories               |
| `checkov`                      | Terraform security/compliance scan — config in `.checkov.yaml`       |
| `terraform-validate-root`      | Root Terraform module under `src/terraform/` (excludes `bootstrap/`) |
| `terraform-validate-bootstrap` | `src/terraform/bootstrap/` module                                    |
| `yamllint`                     | YAML files                                                           |
| `pymarkdown`                   | Markdown files                                                       |
| `shellcheck`                   | Shell scripts                                                        |
| `actionlint`                   | GitHub Actions workflows                                             |
| `commitlint`                   | Commit messages (`commit-msg` stage) — config in `.commitlintrc.json` |

Both `terraform-validate-*` hooks call [scripts/terraform-validate-module.sh](../scripts/terraform-validate-module.sh),
which runs `terraform validate` through the repo-pinned `terraform` (via `mise exec`)
against a single module with lock files in read-only mode. Root and bootstrap are validated independently — changes
in one do not trigger validation of the other.

`checkov` scans `src/terraform/` for AWS misconfigurations. Skipped checks are
enumerated in [`.checkov.yaml`](../.checkov.yaml); each skip is categorised as
either `(intentional)` — a deliberate template default — or `(TODO)` — a
finding worth fixing at the template level. Remove the `(TODO)` skip when the
underlying resource is updated.

Enable in a fresh clone (after `make install`). The `commit-msg` hook type is
required for the `commitlint` hook:

```bash
mise exec -- uv run pre-commit install
mise exec -- uv run pre-commit install --hook-type commit-msg
```

Run against specific files (faster than `--all-files`):

```bash
mise exec -- uv run pre-commit run --files path/to/file1 path/to/file2
```

Or simply `make lint` to run every hook against every file.

### Formatting (Source of Truth)

- Follow `.editorconfig` in the repository root for formatting rules.
- This includes charset, line endings, indentation, trailing whitespace, final newline,
  and file-type-specific overrides.
- If a formatting rule here ever conflicts with `.editorconfig`, `.editorconfig` wins.
- When generating or formatting code, consult the linter configuration files:
  - **Python** — `pyproject.toml` (`[tool.ruff]` and `[tool.ruff.lint]` sections)
  - **YAML** — `.yamllint`
  - **Markdown** — `.pymarkdown`

### Adding a new file type

When introducing a file type that is not yet covered, update **both** config files:

1. **`.editorconfig`** — add a glob section with the appropriate overrides.
2. **`.gitattributes`** — add an entry with `text eol=lf` (or `eol=crlf` for Windows-only
   files, or `binary` for binary assets). Add `diff=<language>` when git has a built-in
   driver for that language.

Do this as part of the same change that adds the first file of that type.

## AI Behaviour Guidelines

- **Minimal changes**: prefer targeted edits over large refactors unless explicitly asked
- **Follow existing patterns**: read the surrounding code before suggesting changes
- **Pre-commit validation**: after modifying any source file, run `mise exec -- uv run pre-commit run --files <changed files>` (or `make lint` for a full sweep) and fix every reported issue before finishing — do not skip or bypass hooks
- **Dev deps**: when adding/removing a Python dev dependency, prefer `mise exec -- uv add --group <group> <pkg>` / `uv remove <pkg>`. If editing `pyproject.toml` by hand, run `make lock` followed by `make install` and commit `pyproject.toml` and `uv.lock` together
- **No secrets**: never generate tokens, passwords, or credentials — use GitHub Actions secrets
- **Skills source of truth**: keep shared skills only in `.claude/skills/`; GitHub Copilot must use these shared skills and must not duplicate skill definitions under `.github/skills/`
- **Commit messages**: use Conventional Commits format `type(scope): subject` (e.g. `fix(ci): handle missing env variable`), with an imperative subject and no trailing period
