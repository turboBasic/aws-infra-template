################################################################################
# Networking
################################################################################

module "networking" {
  source = "./modules/networking"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  public_subnet_cidrs = [
    local.network_cidrs.public_a,
    local.network_cidrs.public_b,
  ]
  private_subnet_cidrs = [
    local.network_cidrs.private_a,
  ]

  tags = local.common_tags
}

################################################################################
# Storage
################################################################################

module "storage" {
  source = "./modules/storage"

  name_prefix = local.name_prefix
  bucket_name = var.bucket_name

  tags = local.common_tags
}
