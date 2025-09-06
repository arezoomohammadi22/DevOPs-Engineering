module "app1" {
  source    = "./modules/nginx"
  namespace = "app1"
  replicas  = 2
  image     = "nginx:1.25-alpine"
}

module "app2" {
  source    = "./modules/nginx"
  namespace = "app2"
  replicas  = 3
  image     = "nginx:1.25-alpine"
}
