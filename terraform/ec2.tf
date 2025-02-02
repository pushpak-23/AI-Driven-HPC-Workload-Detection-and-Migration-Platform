resource "aws_key_pair" "hpc_key" {
  key_name   = "hpc-key"
  public_key = file("~/.ssh/aws_key.pub")  # Replace with your public key path
}

# Controller Node
resource "aws_instance" "controller" {
  ami                    = "ami-0c7217cdde317cfec"  # Ubuntu 22.04 LTS
  instance_type          = "t2.micro"              # Free tier eligible
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.hpc_sg.id]
  key_name               = aws_key_pair.hpc_key.key_name

  root_block_device {
    volume_size = 8  # GB (Free tier includes 30GB)
  }

  tags = {
    Name = "HPC-Controller"
  }
}

# Worker Nodes (2 for redundancy)
resource "aws_instance" "workers" {
  count                  = 2
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.hpc_sg.id]
  key_name               = aws_key_pair.hpc_key.key_name

  root_block_device {
    volume_size = 8
  }

  tags = {
    Name = "HPC-Worker-${count.index + 1}"
  }
}
