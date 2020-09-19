##Private buckets

module "a2i-axiom-bi-dwh" {
  source = "../modules/terraform-aws-s3-bucket"
  bucket = "axiom-bi-dwh"
  acl    = "private"
  force_destroy = "true"

  versioning = {
    enabled = false
  }

  ##Create a default folders
  #key    = "Folder1/"
  #source = "/dev/null"

}

resource "aws_s3_bucket_public_access_block" "a2i-axiom-bi-dwh" {
  bucket = "axiom-bi-dwh"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "a2i-s3-read-axiom-bi-dwh" {
  name        = "a2i-s3-read-axiom-bi-dwh"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket axiom-bi-dwh"

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
                "arn:aws:s3:::axiom-bi-dwh",
                "arn:aws:s3:::axiom-bi-dwh/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-axiom-bi-dwh" {
  name        = "a2i-s3-read-write-axiom-bi-dwh"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket axiom-bi-dwh"

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
                  "arn:aws:s3:::axiom-bi-dwh",
                  "arn:aws:s3:::axiom-bi-dwh/*"
              ]
          }
      ]
}
EOF
}
##Private buckets

module "a2i-a2i-data-audit" {
  source = "../modules/terraform-aws-s3-bucket"
  bucket = "a2i-data-audit"
  acl    = "private"
  force_destroy = "true"

  versioning = {
    enabled = false
  }

  ##Create a default folders
  #key    = "Folder1/"
  #source = "/dev/null"

}

resource "aws_s3_bucket_public_access_block" "a2i-a2i-data-audit" {
  bucket = "a2i-data-audit"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "a2i-s3-read-a2i-data-audit" {
  name        = "a2i-s3-read-a2i-data-audit"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket a2i-data-audit"

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
                "arn:aws:s3:::a2i-data-audit",
                "arn:aws:s3:::a2i-data-audit/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-a2i-data-audit" {
  name        = "a2i-s3-read-write-a2i-data-audit"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket a2i-data-audit"

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
                  "arn:aws:s3:::a2i-data-audit",
                  "arn:aws:s3:::a2i-data-audit/*"
              ]
          }
      ]
}
EOF
}


