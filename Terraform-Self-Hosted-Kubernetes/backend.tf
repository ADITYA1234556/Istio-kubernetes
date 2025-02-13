terraform {
  backend "s3" {
    bucket = "111-aditya-bucket"
    key    = "terraform-self-hosted/state.tfstate"
    region = "eu-west-2"
  }
}