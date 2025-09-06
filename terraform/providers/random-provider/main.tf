provider "random" {}

resource "random_password" "demo" {
  length  = 12
  special = true
}

output "password" {
  value     = random_password.demo.result
  sensitive = true
}
