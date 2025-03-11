variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "eu-west-3" 
}

variable "aws_profile" {
  description = "The AWS CLI profile to use"
  type        = string
  default     = "default"  
}
