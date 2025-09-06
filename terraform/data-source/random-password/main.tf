provider "random" {}

resource "random_password" "pw" {
  length  = 10
  special = false
}

# دوباره استفاده به‌عنوان Data Source
data "terraform_remote_state" "local" {
  backend = "local"
  config = {
    path = "terraform.tfstate"
  }
}
