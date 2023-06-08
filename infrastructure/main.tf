data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["099720109477"] # Canonical
}

module "webservers" {
  source       = "./modules/server"
  ami_id       = data.aws_ami.ubuntu.id
  vpc_id       = data.aws_vpc.default_vpc.id
  keypair_name = var.keypair_name

}

module "instance_refresh" {
  source              = "./modules/lambda"
  ami_id_ssmps        = module.webservers.ami_id_ssmps
  webservers_asg_name = module.webservers.webserver_asg
}

module "cicd_pipeline" {
  source            = "./modules/cicd"
  github_token      = var.github_token
  repository        = var.repository
  github_owner      = var.github_owner
  ami_id_ssmps      = module.webservers.ami_id_ssmps
  region            = var.region
  emailids          = var.emailids
  github_Oauthtoken = var.github_Oauthtoken
  aws_profile       = var.aws_profile
  base_ami_id       = data.aws_ami.ubuntu.id
}
