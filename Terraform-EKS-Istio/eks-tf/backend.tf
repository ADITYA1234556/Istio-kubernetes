terraform {
  backend "s3" {
    bucket = "111-aditya-bucket"
    key    = "terraformistio/state.tfstate"
    region = "eu-west-2"
  }
}