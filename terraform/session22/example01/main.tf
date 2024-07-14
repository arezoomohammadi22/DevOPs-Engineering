provider "local" {
  # No parameters needed
}

resource "null_resource" "example_directory" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/example_dir"
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "local_file" "example_file" {
  content  = "This is an example file."
  filename = "${path.module}/example_dir/example.txt"

  depends_on = [null_resource.example_directory]
}
