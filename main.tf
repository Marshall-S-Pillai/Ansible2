provider "aws" {
  region = "ap-south-1"
}

# Step 1: Create a secret in AWS Secrets Manager
resource "aws_secretsmanager_secret" "powertool" {
  name        = "my-database-secret1"
  description = "A secret for my database password"
}

# Step 2: Store the secret value in Secrets Manager
resource "aws_secretsmanager_secret_version" "powertool_version" {
  secret_id     = aws_secretsmanager_secret.powertool.id
  secret_string = jsonencode({
    db_password = "my-secret-password-123"
  })

  depends_on = [aws_secretsmanager_secret.powertool]
}

# Step 3: Retrieve the secret version
data "aws_secretsmanager_secret_version" "powertool_version" {
  secret_id = aws_secretsmanager_secret.powertool.id

  depends_on = [aws_secretsmanager_secret_version.powertool_version]
}

# Step 4: Output the secret value (marked as sensitive)
output "db_password" {
  value     = jsondecode(data.aws_secretsmanager_secret_version.powertool_version.secret_string)["db_password"]
  sensitive = true
}

# Step 5: Create IAM Role for EC2 instance
resource "aws_iam_role" "ec2_role" {
  name = "ec2_secrets_manager_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Step 6: Attach policy to IAM Role for Secrets Manager access
resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "secrets_manager_policy"
  description = "Policy to allow EC2 instances to access Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "secretsmanager:GetSecretValue"
        Effect   = "Allow"
        Resource = aws_secretsmanager_secret.powertool.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_secrets_manager_attachment" {
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
  role       = aws_iam_role.ec2_role.name
}

# Step 7: Launch EC2 instance with the secret
resource "aws_instance" "powertool_instance" {
  ami                    = "ami-0c2b8ca1dad447f8a"  # Example AMI ID for ap-south-1 region
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_role.ec2_role.name

  user_data = <<-EOF
              #!/bin/bash
              yum install -y jq
              DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "my-database-secret1" --query "SecretString" --output text | jq -r '.db_password')
              if [ -z "$DB_PASSWORD" ]; then
                echo "Error: DB password could not be retrieved from Secrets Manager."
                exit 1
              fi
              echo "DB_PASSWORD=${DB_PASSWORD}" > /etc/db_password.txt
              EOF

  tags = {
    Name = "powertool_instance"
  }
}
