terraform {
  # Default to the local backend so the template works out-of-the-box.
  # Swap for `backend "s3" { ... }` (or another remote backend) when adopting
  # this template for a real project.
  backend "local" {}
}
