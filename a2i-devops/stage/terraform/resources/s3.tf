##Private buckets

resource "aws_s3_bucket_public_access_block" "a2i-axiom-stage-dwh" {
  bucket = "axiom-stage-dwh"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "a2i-s3-read-axiom-stage-dwh" {
  name        = "a2i-s3-read-axiom-stage-dwh"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket axiom-stage-dwh"

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
                "arn:aws:s3:::axiom-stage-dwh",
                "arn:aws:s3:::axiom-stage-dwh/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-axiom-stage-dwh" {
  name        = "a2i-s3-read-write-axiom-stage-dwh"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket axiom-stage-dwh"

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
                  "arn:aws:s3:::axiom-stage-dwh",
                  "arn:aws:s3:::axiom-stage-dwh/*"
              ]
          }
      ]
}
EOF
}
##Private buckets

resource "aws_s3_bucket_public_access_block" "a2i-axiom-dev-dwh" {
  bucket = "axiom-dev-dwh"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "a2i-s3-read-axiom-dev-dwh" {
  name        = "a2i-s3-read-axiom-dev-dwh"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket axiom-dev-dwh"

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
                "arn:aws:s3:::axiom-dev-dwh",
                "arn:aws:s3:::axiom-dev-dwh/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-axiom-dev-dwh" {
  name        = "a2i-s3-read-write-axiom-dev-dwh"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket axiom-dev-dwh"

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
                  "arn:aws:s3:::axiom-dev-dwh",
                  "arn:aws:s3:::axiom-dev-dwh/*"
              ]
          }
      ]
}
EOF
}
##Private buckets


resource "aws_s3_bucket_public_access_block" "a2i-a2i-devops" {
  bucket = "a2i-devops"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "a2i-s3-read-a2i-devops" {
  name        = "a2i-s3-read-a2i-devops"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket a2i-devops"

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
                "arn:aws:s3:::a2i-devops",
                "arn:aws:s3:::a2i-devops/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-a2i-devops" {
  name        = "a2i-s3-read-write-a2i-devops"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket a2i-devops"

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
                  "arn:aws:s3:::a2i-devops",
                  "arn:aws:s3:::a2i-devops/*"
              ]
          }
      ]
}
EOF
}
##Private buckets

resource "aws_s3_bucket_public_access_block" "a2i-a2i-stage-ai" {
  bucket = "a2i-stage-ai"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "a2i-s3-read-a2i-stage-ai" {
  name        = "a2i-s3-read-a2i-stage-ai"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket a2i-stage-ai"

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
                "arn:aws:s3:::a2i-stage-ai",
                "arn:aws:s3:::a2i-stage-ai/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-a2i-stage-ai" {
  name        = "a2i-s3-read-write-a2i-stage-ai"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket a2i-stage-ai"

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
                  "arn:aws:s3:::a2i-stage-ai",
                  "arn:aws:s3:::a2i-stage-ai/*"
              ]
          }
      ]
}
EOF
}
##Private buckets

resource "aws_s3_bucket_public_access_block" "a2i-a2i-stage-personalize" {
  bucket = "a2i-stage-personalize"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "a2i-s3-read-a2i-stage-personalize" {
  name        = "a2i-s3-read-a2i-stage-personalize"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket a2i-stage-personalize"

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
                "arn:aws:s3:::a2i-stage-personalize",
                "arn:aws:s3:::a2i-stage-personalize/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-a2i-stage-personalize" {
  name        = "a2i-s3-read-write-a2i-stage-personalize"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket a2i-stage-personalize"

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
                  "arn:aws:s3:::a2i-stage-personalize",
                  "arn:aws:s3:::a2i-stage-personalize/*"
              ]
          }
      ]
}
EOF
}
##Private buckets

resource "aws_s3_bucket_public_access_block" "a2i-a2i-stage-demand-forecast" {
  bucket = "a2i-stage-demand-forecast"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "a2i-s3-read-a2i-stage-demand-forecast" {
  name        = "a2i-s3-read-a2i-stage-demand-forecast"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket a2i-stage-demand-forecast"

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
                "arn:aws:s3:::a2i-stage-demand-forecast",
                "arn:aws:s3:::a2i-stage-demand-forecast/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-a2i-stage-demand-forecast" {
  name        = "a2i-s3-read-write-a2i-stage-demand-forecast"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket a2i-stage-demand-forecast"

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
                  "arn:aws:s3:::a2i-stage-demand-forecast",
                  "arn:aws:s3:::a2i-stage-demand-forecast/*"
              ]
          }
      ]
}
EOF
}
##Private buckets

resource "aws_s3_bucket_public_access_block" "a2i-a2i-rnd" {
  bucket = "a2i-rnd"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "a2i-s3-read-a2i-rnd" {
  name        = "a2i-s3-read-a2i-rnd"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket a2i-rnd"

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
                "arn:aws:s3:::a2i-rnd",
                "arn:aws:s3:::a2i-rnd/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-a2i-rnd" {
  name        = "a2i-s3-read-write-a2i-rnd"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket a2i-rnd"

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
                  "arn:aws:s3:::a2i-rnd",
                  "arn:aws:s3:::a2i-rnd/*"
              ]
          }
      ]
}
EOF
}
##Private buckets

resource "aws_s3_bucket_public_access_block" "a2i-a2i-hyke-stage-dwh" {
  bucket = "a2i-hyke-stage-dwh"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "a2i-s3-read-a2i-hyke-stage-dwh" {
  name        = "a2i-s3-read-a2i-hyke-stage-dwh"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket a2i-hyke-stage-dwh"

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
                "arn:aws:s3:::a2i-hyke-stage-dwh",
                "arn:aws:s3:::a2i-hyke-stage-dwh/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-a2i-hyke-stage-dwh" {
  name        = "a2i-s3-read-write-a2i-hyke-stage-dwh"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket a2i-hyke-stage-dwh"

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
                  "arn:aws:s3:::a2i-hyke-stage-dwh",
                  "arn:aws:s3:::a2i-hyke-stage-dwh/*"
              ]
          }
      ]
}
EOF
}
##Private buckets

resource "aws_s3_bucket_public_access_block" "a2i-a2i-stage-backup" {
  bucket = "a2i-stage-backup"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "a2i-s3-read-a2i-stage-backup" {
  name        = "a2i-s3-read-a2i-stage-backup"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket a2i-stage-backup"

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
                "arn:aws:s3:::a2i-stage-backup",
                "arn:aws:s3:::a2i-stage-backup/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-a2i-stage-backup" {
  name        = "a2i-s3-read-write-a2i-stage-backup"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket a2i-stage-backup"

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
                  "arn:aws:s3:::a2i-stage-backup",
                  "arn:aws:s3:::a2i-stage-backup/*"
              ]
          }
      ]
}
EOF
}
##Private buckets

resource "aws_s3_bucket_public_access_block" "a2i-a2i-devops-stage" {
  bucket = "a2i-devops-stage"
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "a2i-s3-read-a2i-devops-stage" {
  name        = "a2i-s3-read-a2i-devops-stage"
  path        = "/"
  description = "This policy is used for allowing read only access to user on bucket a2i-devops-stage"

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
                "arn:aws:s3:::a2i-devops-stage",
                "arn:aws:s3:::a2i-devops-stage/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "a2i-s3-read-write-a2i-devops-stage" {
  name        = "a2i-s3-read-write-a2i-devops-stage"
  path        = "/"
  description = "This policy is used for allowing read and write access to user on bucket a2i-devops-stage"

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
                  "arn:aws:s3:::a2i-devops-stage",
                  "arn:aws:s3:::a2i-devops-stage/*"
              ]
          }
      ]
}
EOF
}
