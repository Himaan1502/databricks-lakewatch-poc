# Coordinates of the remote state that holds Stage 1's outputs.
# In CI these are fed from the TF_STATE_* repo variables.

variable "state_resource_group_name" {
  type        = string
  description = "Resource group of the Terraform state storage account."
}

variable "state_storage_account_name" {
  type        = string
  description = "Terraform state storage account name."
}

variable "state_container_name" {
  type        = string
  description = "Terraform state container name."
  default     = "tfstate"
}
