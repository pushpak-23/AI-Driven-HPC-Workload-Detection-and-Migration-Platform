resource "aws_iam_role" "lambda_role" {
  name = "hpc_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_lambda_function" "scale_monitor" {
  filename      = "lambda_function.zip"
  function_name = "hpc_scale_monitor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.9"

  environment {
    variables = {
      CLUSTER_IP = aws_instance.controller.private_ip
    }
  }
}
