provider "tls" {}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "example" {
  private_key_pem = tls_private_key.example.private_key_pem
  subject {
    common_name  = "example.local"
    organization = "MyOrg"
  }
  validity_period_hours = 8760
  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]
}

output "cert_pem" {
  value = tls_self_signed_cert.example.cert_pem
}
