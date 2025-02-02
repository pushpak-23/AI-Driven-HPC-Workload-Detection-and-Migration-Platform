resource "aws_autoscaling_policy" "hpc_scale" {
  name                   = "hpc-autoscale"
  scaling_adjustment     = 2
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.hpc.name
}
