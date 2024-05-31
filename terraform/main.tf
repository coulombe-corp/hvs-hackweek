terraform {
  backend "s3" {
    bucket = "hvs-hackweek-2024-statefiles"
    key    = "hackweek-2024/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "hackweek" {
  bucket = "hvs-hackweek-2024"
}

resource "aws_s3_bucket_cors_configuration" "hackweek" {
  bucket = aws_s3_bucket.hackweek.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_public_access_block" "hackweek" {
  bucket = aws_s3_bucket.hackweek.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "hackweek" {
  bucket = aws_s3_bucket.hackweek.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "hackweek" {
  depends_on = [aws_s3_bucket_ownership_controls.hackweek]

  bucket = aws_s3_bucket.hackweek.id
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "hackweek" {
  bucket = aws_s3_bucket.hackweek.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Principal = "*"
        Action = [
          "s3:*",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.hackweek.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.hackweek.bucket}/*"
        ]
      },
      {
        Sid       = "PublicReadGetObject"
        Principal = "*"
        Action = [
          "s3:GetObject",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.hackweek.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.hackweek.bucket}/*"
        ]
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.hackweek]
}

data "template_file" "index" {
  template = file("${path.module}/index.html.tpl")

  vars = {
    access_key_id = var.access_key_id
  }
}

resource "local_file" "index" {
  filename = "index.html"
  content  = data.template_file.index.rendered
}

resource "aws_s3_bucket_website_configuration" "hackweek" {
  bucket = aws_s3_bucket.hackweek.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "null_resource" "always_run" {
  triggers = {
    timestamp = timestamp()
  }
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.hackweek.id
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"

  lifecycle {
    replace_triggered_by = [
      null_resource.always_run
    ]
  }
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.hackweek.id
  key          = "error.html"
  source       = "error.html"
  content_type = "text/html"
}

output "website_url" {
  value       = aws_s3_bucket_website_configuration.hackweek.website_endpoint
  description = "URL of the static website"
}
