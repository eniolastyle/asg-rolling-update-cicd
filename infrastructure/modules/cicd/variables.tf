variable "github_token" {
  type        = string
  description = "Token for GIT Hub Pipeline."
}

variable "repository" {
  type        = string
  description = "Repository name for GIT Hub Web Hook."
}

variable "github_owner" {
  type        = string
  description = "Repository Owner for GIT Hub Web Hook."
}

variable "github_host_arn" {
  type        = string
  description = "Repository Owner for GIT Hub Web Hook."
  default     = "arn:aws:codestar-connections:us-east-1:761410730749:connection/6880542f-80f5-4dd6-809f-506690dee393"
}

variable "github_owner_account_id" {
  type        = string
  description = "Repository Owner for GIT Hub Web Hook."
  default     = "761410730749"
}


variable "ami_id_ssmps" {
  type        = string
  description = "Parameter store name for web server AMI ID."
}

variable "region" {
  type        = string
  description = "Name of the Region to be deployed."
}

variable "emailids" {
  type        = string
  description = "List of email addresses as string(space separated) to be notified with new image."
}

variable "github_Oauthtoken" {
  type        = string
  description = "Git Hub token for GIT hub connection."
}

variable "aws_profile" {
  type        = string
  description = "AWS Profile to be used to create resources."
}

variable "base_ami_id" {
  type        = string
  description = "Base AMI ID for web server."
}
