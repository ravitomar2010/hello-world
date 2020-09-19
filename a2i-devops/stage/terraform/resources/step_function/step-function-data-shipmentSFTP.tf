resource "aws_sfn_state_machine" "data-shipmentSFTP" {
  name     = "${var.platform}-data-shipmentSFTP"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "Shipment States Language using a parallel state to execute two branches at the same time.",
  "StartAt": "Parallel",
  "States": {
    "Parallel": {
      "Type": "Parallel",
      "Next": "NokiatoSFTPLoc",
      "Branches": [
                  {
          "StartAt": "HUAWEI_UNCOMPRESS",
          "States": {
          "HUAWEI_UNCOMPRESS": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:HuaweiUncompress:$LATEST",
              "Next": "HUAWEI_XLStoCSV"

            },
          "HUAWEI_XLStoCSV": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:HuaweiSFTP_xlstocsv:$LATEST",
              "Next": "HUAWEI_GOODnBAD"
            },

          "HUAWEI_GOODnBAD": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:HuaweiGoodnBAd:$LATEST",
              "End": true

            }
          }

        },
        {
          "StartAt": "NOKIA_XLStoCSV",
          "States": {
            "NOKIA_XLStoCSV": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:NokiaSFTPxlstocsv:$LATEST",
              "End": true

            }
          }
        },
        {
          "StartAt": "SamsungXLSXtoCSV",
          "States": {
            "SamsungXLSXtoCSV": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:SAMSUNGSFTPxlstocsv:$LATEST",
              "End": true

            }
          }
        }

      ]
    },
      "NokiatoSFTPLoc": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-NokiaGoodNbad:$LATEST",
      "Next": "SamsunfSFTPLoc"
    },
      "SamsunfSFTPLoc": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-SamsungGoodNbad:$LATEST",
     "End": true
    }
  }
}


EOF
}
