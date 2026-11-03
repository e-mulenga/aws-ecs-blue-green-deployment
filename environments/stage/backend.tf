terraform {
  backend "s3" {
    bucket       = "<your-state-bucket>"
    key          = "<your-bucket-key>"
    region       = "your-bucket-region"
    encrypt      = true
    use_lockfile = true
  }
}
