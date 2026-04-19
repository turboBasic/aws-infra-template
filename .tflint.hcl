config {
  # Lint child modules when module directories are scanned.
  call_module_type = "all"
}

# Keep core Terraform rules explicit for predictable lint behavior.
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}
