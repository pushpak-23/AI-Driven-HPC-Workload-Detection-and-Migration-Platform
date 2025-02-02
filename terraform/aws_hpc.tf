resource "aws_instance" "hpc_node" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "c5.9xlarge"
  count         = 2
  tags = {
    Name = "hpc-node-${count.index}"
  }
}
