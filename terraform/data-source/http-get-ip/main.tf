provider "http" {}

data "http" "myip" {
  url = "https://api.ipify.org?format=json"
}

output "my_ip" {
  value = jsondecode(data.http.myip.body).ip
}
