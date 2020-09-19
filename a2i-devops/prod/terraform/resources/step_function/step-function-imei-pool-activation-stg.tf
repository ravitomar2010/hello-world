resource "aws_sfn_state_machine" "imei-pool-activation-stg" {
  name     = "${var.platform}-data-imei-pool-activation-stg"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "Shipment and Activation File Ingestion for Samsung, Huawei, Nokia",
  "StartAt": "ActivationParallel",
  "States": {
    "ActivationParallel": {
      "Type": "Parallel",
      "Next": "ACTIVATION_NOKIA_HUAWEI_PUID",
      "Branches": [
        {
          "StartAt": "ACTIVATION_SAMSUNG",
          "States": {
          "ACTIVATION_SAMSUNG": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-activation_samsung:$LATEST",
              "End": true
            }
          }
        },
        {
          "StartAt": "ACTIVATION_HUAWEI",
          "States": {
          "ACTIVATION_HUAWEI": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-activation_huawei:$LATEST",
              "End": true
            }
          }
        }
		,
                  {
          "StartAt": "ACTIVATION_NOKIA",
          "States": {
          "ACTIVATION_NOKIA": {
            "Type": "Task",
            "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-activation_nokia:$LATEST",
              "End": true
            }
          }
        }
      ]
    },
  "ACTIVATION_NOKIA_HUAWEI_PUID": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-activation_nokia_huawei_puid:$LATEST",
       "End": true
    }
  }
}
EOF
}
