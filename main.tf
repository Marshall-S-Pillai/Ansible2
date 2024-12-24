provider "aws" {
  region = "us-east-1"
}

# Step 1: Create a secret in AWS Secrets Manager with the new name
resource "aws_secretsmanager_secret" "powertool" {
  name        = "my-database-secret1"
  description = "A secret for my database password"
}

# Step 2: Store the secret value in Secrets Manager with the new version name
resource "aws_secretsmanager_secret_version" "powertool_version" {
  secret_id     = aws_secretsmanager_secret.powertool.id
  secret_string = jsonencode({
    db_password = "my-secret-password-123"
  })

  depends_on = [aws_secretsmanager_secret.powertool]
}

# Step 3: Create IAM Role for EC2 to access Secrets Manager
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

# Step 4: Attach Secrets Manager access policy to the IAM Role
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

# Step 5: Launch EC2 instance with IAM role to access Secrets Manager
resource "aws_instance" "powertool_instance" {
  ami                    = "ami-0fd05997b4dff7aac"  # Updated AMI ID
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_role.ec2_role.name

  user_data = <<-EOF
              #!/bin/bash
              
              # Install AWS CLI and jq if not already installed
              yum install -y aws-cli jq

              # Fetch the DB password from Secrets Manager
              DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "my-database-secret1" --query "SecretString" --output text | jq -r .db_password)

              # Store the DB password in a file
              echo "DB_PASSWORD=${DB_PASSWORD}" > /etc/db_password.txt

EOF

  tags = {
    Name = "powertool_instance"
  }
}

# Step 6: Output the DB password value (Sensitive)
output "db_password" {
  value     = jsondecode(aws_secretsmanager_secret_version.powertool_version.secret_string)["db_password"]
  sensitive = true
}
