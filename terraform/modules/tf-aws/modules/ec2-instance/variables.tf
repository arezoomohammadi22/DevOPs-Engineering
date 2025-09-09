variable "ami" {
  description = "AMI ID"
  type        = string
}

variable "instance_type" {
  description = "نوع ماشین EC2"
  type        = string
  default     = "t2.micro"
}

variable "instance_name" {
  description = "نام ماشین"
  type        = string
  default     = "my-ec2"
}
