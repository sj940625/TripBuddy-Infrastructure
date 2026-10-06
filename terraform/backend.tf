terraform {
  backend "s3" {
    # Public portfolio example. Replace with your own globally unique bucket/key.
    bucket       = "tripbuddy-terraform-state-your-unique-suffix"
    key          = "dev/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
