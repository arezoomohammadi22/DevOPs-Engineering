provider "aws" {
  region = "us-east-1"
}

module "web_server" {
  source        = "./modules/ec2-instance"
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  instance_name = "web-server-1"
}

output "web_server_ip" {
  value = module.web_server.instance_public_ip
}
