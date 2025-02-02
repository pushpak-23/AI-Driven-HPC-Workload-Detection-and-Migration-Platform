resource "aws_security_group" "hpc_sg" {
  name        = "hpc-cluster-sg"
  description = "Allow SLURM and SSH traffic"
  vpc_id      = aws_vpc.hpc_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SLURM"
    from_port   = 6817
    to_port     = 6818
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "HPC-Cluster-SG"
  }
}
