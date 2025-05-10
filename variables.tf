variable "location" {
  type        = string
  description = "Resource group location"
  default     = "northeurope"
}

variable "prefix" {
  type        = string
  description = "Prefix for all resources"
  default     = "d01"
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
  default     = "f32f6566-8fa0-4198-9c91-a3b8ac69e89a"
}

variable "tags" {
  type        = map(string)
  description = "Tags for all resources"
  default = {
    Environment  = "DEV"
    Owner        = "Terraform"
    Autoshutdown = "OFF"
  }
}
