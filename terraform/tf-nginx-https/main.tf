terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "docker" {}
provider "tls"    {}
provider "local"  {}

# ====== DEV: Self-signed certificate for HTTPS testing ======
resource "tls_private_key" "selfsigned_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "selfsigned_cert" {
  private_key_pem = tls_private_key.selfsigned_key.private_key_pem

  subject {
    common_name  = var.domain
    organization = "Local Dev"
  }

  validity_period_hours = var.dev_self_signed_days * 24
  is_ca_certificate     = false

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]

  dns_names = [var.domain, "www.${var.domain}"]
}

locals {
  cert_dir  = abspath("${path.module}/certs")
  fullchain = "${local.cert_dir}/fullchain.pem"
  privkey   = "${local.cert_dir}/privkey.pem"
}

resource "local_file" "fullchain_pem" {
  content  = tls_self_signed_cert.selfsigned_cert.cert_pem
  filename = local.fullchain
}

resource "local_file" "privkey_pem" {
  content         = tls_private_key.selfsigned_key.private_key_pem
  filename        = local.privkey
  file_permission = "0600"
}

# Render Nginx config with the chosen domain
resource "local_file" "nginx_conf_rendered" {
  content  = templatefile("${path.module}/files/nginx.conf", { domain = var.domain })
  filename = "${path.module}/files/.rendered_nginx.conf"
}

resource "docker_image" "nginx" {
  name         = "nginx:stable"
  keep_locally = true
}

resource "docker_container" "nginx" {
  name  = var.container_name
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.http_port
    protocol = "tcp"
  }
  ports {
    internal = 443
    external = var.https_port
    protocol = "tcp"
  }

  mounts {
    target = "/etc/nginx/conf.d/default.conf"
    source = abspath("${path.module}/files/.rendered_nginx.conf")
    type   = "bind"
  }

  mounts {
    target = "/usr/share/nginx/html"
    source = abspath("${path.module}/files")
    type   = "bind"
  }

  mounts {
    target = "/etc/nginx/ssl/fullchain.pem"
    source = local.fullchain
    type   = "bind"
  }
  mounts {
    target = "/etc/nginx/ssl/privkey.pem"
    source = local.privkey
    type   = "bind"
  }

  depends_on = [
    local_file.fullchain_pem,
    local_file.privkey_pem,
    local_file.nginx_conf_rendered
  ]

  restart = "unless-stopped"
}