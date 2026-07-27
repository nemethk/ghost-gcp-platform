resource "null_resource" "hello_world" {
  provisioner "local-exec" {
    command     = "echo 'hello world from your cloud build terraform pipeline'"
    interpreter = ["sh", "-c"]
  }
}