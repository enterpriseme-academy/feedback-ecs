variable "name" {
  type        = string
  description = "Name for the vpc"
  default     = "feedback-app"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the VPC and resources"
  default     = {}
}

variable "port" {
  type        = number
  description = "Port for the application"
  default     = 5000
}