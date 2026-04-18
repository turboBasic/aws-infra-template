locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }

  # Network CIDR blocks derived from var.vpc_cidr.
  network_cidrs = {
    public_a  = cidrsubnet(var.vpc_cidr, 8, 1)  # 10.0.1.0/24
    public_b  = cidrsubnet(var.vpc_cidr, 8, 2)  # 10.0.2.0/24
    private_a = cidrsubnet(var.vpc_cidr, 8, 10) # 10.0.10.0/24
  }
}
