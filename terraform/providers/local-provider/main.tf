provider "local" {}

resource "local_file" "note" {
  filename = "hello.txt"
  content  = "سلام! این فایل رو Terraform ساخت."
}
