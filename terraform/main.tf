provider "aws" {
  profile = var.aws-profile
  region  = var.aws-region
}
provider "aws" {
  profile = var.aws-profile
  alias   = "us_east_1"
  region  = "us-east-1" #Lambda Edge requires this specific region
}

## S3 Bucket
# Create an S3 bucket to serve the custom application
resource "aws_s3_bucket" "custom-app-bkt" {
  bucket        = var.custom-app-bkt
  acl           = "public-read"
  force_destroy = var.s3_force_destroy
  versioning {
    enabled = false
  }

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [tags]
  }
}


## Lambda Edge
# Zip the Lambda@Edge code created by mc-scripts
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "../lambda-edge-headers.js"
  output_path = "lambda-edge-headers.zip"
}

# Lookup policy
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
    }
  }
}

# Create new policy for lambda
resource "aws_iam_role" "lambda_service_role" {
  name               = "lambda_service_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
  provider           = aws.us_east_1

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Create lambda function
resource "aws_lambda_function" "edge_headers" {
  filename         = "lambda-edge-headers.zip"
  function_name    = "edge_headers"
  role             = aws_iam_role.lambda_service_role.arn
  handler          = "lambda-edge-headers.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "nodejs14.x"
  publish          = true
  provider         = aws.us_east_1

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# cloudwatch permission for debugging
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.edge_headers.function_name
  principal     = "events.amazonaws.com"
  provider      = aws.us_east_1
}

## CloudFront
# Certificate should already be issued, lookup by domain
data "aws_acm_certificate" "cert" {
  domain   = var.acm_certificate_domain
  statuses = ["ISSUED"]
}

# Create a cloudfront distribution
resource "aws_cloudfront_distribution" "web_distribution" {
  enabled             = true
  is_ipv6_enabled     = false
  wait_for_deployment = false
  default_root_object = "index.html"
  price_class         = "PriceClass_100" #https://docs.aws.amazon.com/AmazonCloudFront/ladev/DeveloperGuide/PriceClass.html

  origin {
    domain_name = aws_s3_bucket.custom-app-bkt.bucket_regional_domain_name
    origin_id   = "origin-bucket-${aws_s3_bucket.custom-app-bkt.id}"
    custom_origin_config {
      origin_protocol_policy = "http-only" # The protocol policy that you want CloudFront to use when fetching objects from the origin server (a.k.a S3 in our situation). HTTP Only is the default setting when the origin is an Amazon S3 static website hosting endpoint, because Amazon S3 doesn’t support HTTPS connections for static website hosting endpoints.
      http_port              = 80
      https_port             = 443
      origin_ssl_protocols   = ["TLSv1.2", "TLSv1.1", "TLSv1"]
    }
  }

  custom_error_response {
    error_caching_min_ttl = "0"
    error_code            = "404"
    response_code         = "200"
    response_page_path    = "/index.html"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "origin-bucket-${aws_s3_bucket.custom-app-bkt.id}"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    lambda_function_association {
      event_type   = "origin-response"
      lambda_arn   = aws_lambda_function.edge_headers.qualified_arn
      include_body = false
    }
  }

  aliases = [var.website-domain]

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  }

  lifecycle {
    ignore_changes = [
      tags,
      viewer_certificate,
    ]
  }
}

## Route 53
# Hosted zone should already exist, lookup by name
data "aws_route53_zone" "selected" {
  name = var.route53-zone-name
}

# Add A record to hosted zone pointed at cloudwatch
resource "aws_route53_record" "custom-app" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.website-domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.web_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.web_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
