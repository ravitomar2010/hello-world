##Private buckets

module "a2i-replace_me_name" {
  source = "../modules/terraform-aws-s3-bucket"
  bucket = "replace_me_name"
  acl    = "private"
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

resource "aws_iam_policy" "a2i-s3-read-replace_me_name" {
  name        = "a2i-s3-read-replace_me_name"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket replace_me_name"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowUsersToListAllTheBuckets",
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets",
                "s3:ListBucket",
                "s3:HeadBucket"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowReadAccessToUsersOnSpecificBucket",
            "Effect": "Allow",
            "Action": [
                    "s3:GetObjectAcl",
                    "s3:GetObject",
                    "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::replace_me_name",
                "arn:aws:s3:::replace_me_name/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-replace_me_name" {
  name        = "a2i-s3-read-write-replace_me_name"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket replace_me_name"

  policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "AllowUsersToListAllTheBuckets",
              "Effect": "Allow",
              "Action": [
                  "s3:ListAllMyBuckets",
                  "s3:ListBucket",
                  "s3:HeadBucket"
              ],
              "Resource": "*"
          },
          {
              "Sid": "AllowReadWriteAccessToUsersOnSpecificBucket",
              "Effect": "Allow",
              "Action": [
                  "s3:ReplicateObject",
                  "s3:PutObject",
                  "s3:GetObject",
                  "s3:RestoreObject",
                  "s3:ListBucket",
                  "s3:DeleteObject"
              ],
              "Resource": [
                  "arn:aws:s3:::replace_me_name",
                  "arn:aws:s3:::replace_me_name/*"
              ]
          }
      ]
}
EOF
}
