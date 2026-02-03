# 1. VPC Module
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

# 2. Security Module
module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  ssh_allowed_cidrs = var.ssh_allowed_cidrs

}


# 4. Compute Module
module "compute" {
  source       = "./modules/compute"
  project_name = var.project_name

  # Single Subnet IDs
  public_subnet_id  = module.vpc.public_subnet_id
  private_subnet_id = module.vpc.private_subnet_id

  bastion_sg_id        = module.security.bastion_sg_id
  k3s_node_sg_id       = module.security.k3s_node_sg_id
  jenkins_sg_id        = module.security.jenkins_sg_id
  key_name             = var.key_name

  # Scripts
  jenkins_script = file("${path.root}/scripts/bootstrap-jenkins.sh")
  master_script  = file("${path.root}/scripts/k3s_master.sh")
  worker_script  = file("${path.root}/scripts/k3s_worker.sh")
}

# 5. NLB Module
module "nlb" {
  source           = "./modules/nlb"
  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_id

  # ATTACH ONLY WORKER + MONITORING NODES TO NLB
  worker_ids = module.compute.worker_ids
}


