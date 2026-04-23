
resource "aws_iam_user" "gts_iam_user" {
  name = "gotosocial-cdn-user"
}

resource "aws_iam_access_key" "gts_iam_access_key" {
  user = aws_iam_user.gts_iam_user.name
}

data "aws_iam_policy_document" "gts_s3_policy" {
  statement {
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.gts_s3.arn]
  }

  statement {
    actions   = ["s3:*"]
    resources = ["${aws_s3_bucket.gts_s3.arn}/*", aws_s3_bucket.gts_s3.arn]
  }
}

resource "aws_iam_user_policy" "gts_iam_user_policy" {
  name   = "gotosocial-cdn-user-policy"
  user   = aws_iam_user.gts_iam_user.name
  policy = data.aws_iam_policy_document.gts_s3_policy.json
}

resource "random_string" "gts_s3_suffix" {
  length  = 8
  special = true
  upper   = true
}

resource "aws_s3_bucket" "gts_s3" {
  provider = aws.eu_west_2
  region   = "eu-west-2"
  bucket   = "gotosocial-cdn-${random_string.gts_s3_suffix.result}"

  tags = {
    Name        = "GotoSocial CDN"
    Environment = "production"
  }
}

resource "aws_s3_bucket_public_access_block" "gts_cdn" {
  provider = aws.eu_west_2
  region   = "eu-west-2"
  bucket   = aws_s3_bucket.gts_s3.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "gts_cdn" {
  provider = aws.eu_west_2
  region   = "eu-west-2"
  bucket   = aws_s3_bucket.gts_s3.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_policy" "gts_cdn" {
  provider = aws.eu_west_2
  region   = "eu-west-2"
  bucket   = aws_s3_bucket.gts_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.gts_s3.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.gts_cdn]
}

resource "aws_s3_object" "gts_cdn_index" {
  provider = aws.eu_west_2
  region   = "eu-west-2"
  bucket   = aws_s3_bucket.gts_s3.id
  key      = "index.html"
  source   = "files/gts_cdn/index.html"
}

resource "aws_s3_object" "gts_cdn_error" {
  provider = aws.eu_west_2
  region   = "eu-west-2"
  bucket   = aws_s3_bucket.gts_s3.id
  key      = "error.html"
  source   = "files/gts_cdn/error.html"
}
