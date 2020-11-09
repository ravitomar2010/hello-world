import sys
import json
print('Number of arguments:', len(sys.argv), 'arguments.')

# print("Bucket is ",sys.argv[1])
# print("Folder is ",sys.argv[2])
bucketName=sys.argv[1]
folderName=sys.argv[2]

data = {"s3Bucket": bucketName ,"s3FolderPath": folderName }

location = data["s3FolderPath"].split("/")
condition = [""]
prevPath = ""

print("Creating policy draft")

for path in location:
  prevPath += path + "/"
  condition.append(prevPath)

output = {
   "Version" : "2012-10-17",
   "Statement": [
        {
            "Sid": "AllowUserToSeeBucketListInTheConsole",
            "Action": [
                "s3:ListAllMyBuckets",
                "s3:GetBucketLocation"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::*"
            ]
        },
        {
            "Sid": "AllowRootAndInternalListingOfBucketFolders",
            "Action": [
                "s3:ListBucket"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::" + data["s3Bucket"]
            ],
            "Condition": {
                "StringEquals": {
                    "s3:prefix": condition,
                    "s3:delimiter": [
                        "/"
                    ]
                }
            }
        },
        {
            "Sid": "AllowListingOfFolderAndFiles",
            "Action": [
                "s3:ListBucket"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::" + data["s3Bucket"]
            ],
            "Condition": {
                "StringLike": {
                    "s3:prefix": [
                        data["s3FolderPath"] + "/*"
                    ]
                }
            }
        },
        {
            "Sid": "AllowReadWriteInSpecificFolder",
            "Effect": "Allow",
            "Action": [
                "s3:*Object"
            ],
            "Resource": [
                "arn:aws:s3:::" + data["s3Bucket"]+ "/" + data["s3FolderPath"] + "/*"
            ]
        }
    ]
}
app_json = json.dumps(output, sort_keys=True)
#print(app_json)
print("Created policy draft")
with open('tmp_policy.txt', 'w') as fp:
    json.dump(output, fp)
