
terraform {
  # Stores state on s3
  backend "s3" {
    config = {
      key                  = "terraform.tfstate"
      workspace_key_prefix = "tfstate"
    }
  }
}
