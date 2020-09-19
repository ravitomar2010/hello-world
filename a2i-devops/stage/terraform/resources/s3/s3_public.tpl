##Private buckets

module "a2i-replace_me_name" {
  source = "../modules/terraform-aws-s3-bucket"
  bucket = "replace_me_name"
  acl    = "public"
  force_destroy = "true"

  versioning = {
    enabled = false
  }

  ##Create a default folders
  #key    = "Folder1/"
  #source = "/dev/null"

}

resource "aws_s3_bucket_public_access_block" "a2i-replace_me_name" {
  bucket = "replace_me_name"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
