resource "aws_spot_instance_request" "hpc" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "c5.9xlarge"
  spot_price    = "0.50"
}
