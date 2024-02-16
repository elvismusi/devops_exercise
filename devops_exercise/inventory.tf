resource "local_sensitive_file" "private_key" {
  content = tls_private_key.key.private_key_pem
  filename          = format("%s/%s/%s", abspath(path.root), ".ssh", "id_rsa")
  file_permission   = "0600"
}

resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tftpl", {
    ip_addrs = aws_instance.ec2_instance.public_ip
    ssh_keyfile = local_sensitive_file.private_key.filename
  })
  filename = format("%s/%s", abspath(path.root), "inventory.ini")
}
