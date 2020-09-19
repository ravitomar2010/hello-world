resource "aws_sfn_state_machine" "data-shipment-file" {
  name     = "${var.platform}-data-shipment-file"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "Shipment States Language using a parallel state to execute two branches at the same time.",
  "StartAt": "Parallel",
  "States": {
    "Parallel": {
      "Type": "Parallel",
      "Next": "SHIPMENT_FILE_S3toSTAGE_TABLE",
      "Branches": [
                  {
          "StartAt": "HUAWEI_UNCOMPRESS",
          "States": {
          "HUAWEI_UNCOMPRESS": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-HuaweiUncompress:$LATEST",
              "Next": "HUAWEI_XLStoCSV"

            },
          "HUAWEI_XLStoCSV": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-HuaweiXLSXtoCSV:$LATEST",
              "Next": "HUAWEI_GOODnBAD"
            },

          "HUAWEI_GOODnBAD": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-HuaweiGoodNbad:$LATEST",
              "Next": "HUAWEI_DIVISIONOfSHIPMENT"

            },
          "HUAWEI_DIVISIONOfSHIPMENT": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-HUAWEI-divisionOfShipment:$LATEST",
              "End": true
            }
          }

        },
        {
          "StartAt": "NOKIA_XLStoCSV",
          "States": {
            "NOKIA_XLStoCSV": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-xlsToCsv:$LATEST",
              "End": true

            }
          }
        },
        {
          "StartAt": "SamsungXLSXtoCSV",
          "States": {
            "SamsungXLSXtoCSV": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-SamsungXLSXtoCSV:$LATEST",
              "End": true

            }
          }
        }

      ]
    },

      "SHIPMENT_FILE_S3toSTAGE_TABLE": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-shipment-s3toStage:$LATEST",
      "Next": "SHIPMENT_FILE_stageToMerge"
    },
      "SHIPMENT_FILE_stageToMerge": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-shipment-stageToMerge:$LATEST",
      "Next": "SHIPMENT_FILE_shipment-mergeToDBO"
    },
      "SHIPMENT_FILE_shipment-mergeToDBO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-shipment-mergeToDBO:$LATEST",
     "Next": "SHIPMENT_FILE_shipment-imeiToPairing"
    },
    "SHIPMENT_FILE_shipment-imeiToPairing": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-shipment-imeiToPairing:$LATEST",
      "End": true
    }
  }
}
EOF
}
