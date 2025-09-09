# Number of replicas per workspace
variable "replica_count" {
  type = map(number)
  default = {
    dev     = 1
    staging = 2
    prod    = 3
  }
}

# Image tag per workspace
variable "image_tag" {
  type = map(string)
  default = {
    dev     = "nginx:1.25"
    staging = "nginx:1.25"
    prod    = "nginx:1.25"
  }
}
