terraform {
    backend "s3" {
        bucket = "dummy"
        key    = "dummy"
        region = "us-west-2"
    }
}
