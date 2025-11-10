variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "AWS availability zone (must match region)"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "EC2 instance type (g6e.4xlarge or p5.4xlarge recommended)"
  type        = string
  default     = "g6e.2xlarge"

  validation {
    condition     = contains(["g6e.2xlarge", "g6e.4xlarge", "p5.4xlarge", "p4d.24xlarge"], var.instance_type)
    error_message = "Instance type must be a GPU instance suitable for Wan2.2 (g6e.4xlarge, p5.4xlarge, or p4d.24xlarge)."
  }
}
