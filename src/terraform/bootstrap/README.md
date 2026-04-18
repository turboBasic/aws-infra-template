# Bootstrap Terraform Infrastructure

Persistent Terraform state backend for this project. Apply once; after the
initial apply, the root module in [../](..) uses the S3 bucket and DynamoDB
table created here as its backend.

## What this module creates

- **S3 bucket** (`<project>-<env>-tfstate-<account-id>`) — stores the root-module
  state file. Versioned, KMS-encrypted, public access blocked.
- **DynamoDB table** (`<project>-<env>-tflock`) — lock table used by the S3
  backend to prevent concurrent writes.
- **S3 bucket** (`<project>-<env>-bootstrap-tfstate-<account-id>`) — backup
  target for *this module's* own state file (bootstrap uses the local backend;
  see "State management" below).

## Prerequisites

- AWS CLI configured with appropriate credentials
- `mise` and `uv` bootstrapped (see repo root [README.md](../../../README.md))
- Terraform pinned via [../../../.mise.toml](../../../.mise.toml)

## Step 1 — Configure bootstrap variables

```bash
cd src/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
aws_region   = "eu-central-1"
environment  = "dev"
project_name = "aws-infra-template"
state_key    = "root/terraform.tfstate"
```

## Step 2 — Initialize and apply bootstrap

```bash
mise exec -- terraform init
mise exec -- terraform plan
mise exec -- terraform apply
```

## Step 3 — Back up bootstrap state to S3

Bootstrap uses the **local** backend, so `terraform.tfstate` lives on your
machine. Back it up to the backup bucket after each apply:

```bash
# Get the upload command from outputs
mise exec -- terraform output -json bootstrap_state_backup_commands | jq -r '.upload'

# Or run it directly (substitute account ID)
aws s3 cp terraform.tfstate \
  s3://aws-infra-template-dev-bootstrap-tfstate-<account-id>/terraform.tfstate
```

## Step 4 — Capture backend configuration for the root module

```bash
mise exec -- terraform output -json backend_config
```

Example output:

```json
{
  "bucket": "aws-infra-template-dev-tfstate-123456789012",
  "dynamodb_table": "aws-infra-template-dev-tflock",
  "encrypt": true,
  "key": "root/terraform.tfstate",
  "region": "eu-central-1"
}
```

## Step 5 — Configure the root module's backend

Edit [../backend.tf](../backend.tf) and replace the `backend "local" {}`
stub with an S3 backend using the values from Step 4:

```hcl
terraform {
  backend "s3" {
    bucket         = "aws-infra-template-dev-tfstate-123456789012"
    key            = "root/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "aws-infra-template-dev-tflock"
    encrypt        = true
  }
}
```

Then re-initialize the root module:

```bash
cd ..
mise exec -- terraform init -migrate-state
```

## State management summary

### Bootstrap state (local backend)

- **Location**: `src/terraform/bootstrap/terraform.tfstate` (gitignored)
- **Backup**: S3 bucket created by this module
- **Managed**: Manually, rarely changes
- **Purpose**: Persistent infrastructure (state backend for everything else)

### Root-module state (S3 backend)

- **Location**: S3 bucket created by this module
- **Locking**: DynamoDB table created by this module
- **Managed**: Automatically by Terraform

## Restoring bootstrap state from backup

If you lose the local `terraform.tfstate` but the resources still exist:

```bash
cd src/terraform/bootstrap
BUCKET="aws-infra-template-dev-bootstrap-tfstate-<account-id>"
aws s3 cp "s3://${BUCKET}/terraform.tfstate" terraform.tfstate
mise exec -- terraform show
```

## Destroying bootstrap

> **Warning**: this destroys the state backend. Destroy the root module first,
> then clear its state from the S3 bucket, then destroy bootstrap.

```bash
# 1. Destroy the root module
cd src/terraform
mise exec -- terraform destroy

# 2. Empty the state bucket (required — it has versioning)
aws s3 rm "s3://$(cd bootstrap && mise exec -- terraform output -raw state_bucket_name)" --recursive

# 3. Destroy bootstrap (will fail while `prevent_destroy = true` — remove
#    those lifecycle blocks in state.tf and bootstrap-state-bucket.tf first)
cd bootstrap
mise exec -- terraform destroy
```

## Troubleshooting

### State locking issues

```bash
# List locks (replace <table> with dynamodb_table_name output)
aws dynamodb scan --table-name <table>

# Force-unlock using the Lock ID from the error message
mise exec -- terraform force-unlock <lock-id>
```

### Bootstrap state out of sync

Two recovery options:

1. **Restore from S3 backup** — see "Restoring bootstrap state" above.
2. **Import resources manually**:

   ```bash
   mise exec -- terraform import aws_s3_bucket.terraform_state <state-bucket-name>
   mise exec -- terraform import aws_s3_bucket.bootstrap_state <backup-bucket-name>
   mise exec -- terraform import aws_dynamodb_table.terraform_locks <lock-table-name>
   ```

## Security notes

- `terraform.tfstate` contains resource IDs and config — never commit it
  (already covered by the repo-root [.gitignore](../../../.gitignore)).
- Both S3 buckets block all public access and enable encryption + versioning.
