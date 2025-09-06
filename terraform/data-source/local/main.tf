provider "local" {}

data "local_file" "example" {
  filename = "${path.module}/hello.txt"
}

output "file_content" {
  value = data.local_file.example.content
}
