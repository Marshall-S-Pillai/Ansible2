terraform {
  backend "s3" {
    bucket         = "powertool99"
    key            = "ansible2/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "powertool"
  }
}
