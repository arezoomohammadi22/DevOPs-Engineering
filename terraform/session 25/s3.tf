provider "aws" {
  region = "us-west-2"  # specify your desired AWS region
}

resource "aws_s3_bucket" "example" {
  bucket = "my-unique-bucket-name"  # replace with your unique bucket name

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.example.bucket
}
