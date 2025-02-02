# Shared EBS Volume (Logical Volume)
resource "aws_ebs_volume" "shared_storage" {
  availability_zone = "us-east-1a"
  size              = 10  # GB (Stay within free tier)
  type              = "gp2"

  tags = {
    Name = "HPC-Shared-Storage"
  }
}

resource "aws_volume_attachment" "controller_attach" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.shared_storage.id
  instance_id = aws_instance.controller.id
}
