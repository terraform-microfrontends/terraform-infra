terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

variable "subdomain" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

resource "aws_s3_bucket" "terraform_mfes_static" {
  bucket = "${var.subdomain}.microfrontends.app"
}

resource "aws_s3_bucket_ownership_controls" "terraform_mfes_static" {
  bucket = aws_s3_bucket.terraform_mfes_static.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_mfes_static" {
  bucket = aws_s3_bucket.terraform_mfes_static.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "terraform_mfes_static" {
  depends_on = [
    aws_s3_bucket_ownership_controls.terraform_mfes_static,
    aws_s3_bucket_public_access_block.terraform_mfes_static,
  ]

  bucket = aws_s3_bucket.terraform_mfes_static.id
  acl    = "public-read"
}

resource "aws_s3_bucket_cors_configuration" "terraform_mfes_static" {
  bucket = aws_s3_bucket.terraform_mfes_static.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_website_configuration" "terraform_mfes_static" {
  bucket = aws_s3_bucket.terraform_mfes_static.id

  index_document {
    suffix = "index.html"
  }
}

# https://support.cloudflare.com/hc/en-us/articles/360037983412-Configuring-an-Amazon-Web-Services-static-site-to-use-Cloudflare
# https://flosell.github.io/iam-policy-json-to-terraform/
data "aws_iam_policy_document" "terraform_mfes_static_cloudflare" {
  statement {
    sid       = "PublicReadGetObject"
    effect    = "Allow"
    resources = ["${aws_s3_bucket.terraform_mfes_static.arn}/*"]
    actions   = ["s3:GetObject"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudflare_read_terraform_mfes_static" {
  bucket = aws_s3_bucket.terraform_mfes_static.id
  policy = data.aws_iam_policy_document.terraform_mfes_static_cloudflare.json
}

resource "cloudflare_record" "baseplate_static" {
  zone_id = var.cloudflare_zone_id
  name    = "${var.subdomain}.microfrontends.app"
  value   = aws_s3_bucket_website_configuration.terraform_mfes_static.website_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
}