resource "aws_sfn_state_machine" "dss-transformation" {
  name     = "${var.platform}-data-dss-transformation"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "DSS Transaction Stage -> DBO",
  "StartAt": "DSS_TRANSACTION_STAGE",
  "States": {
    "DSS_TRANSACTION_STAGE": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-dss-transformation-stage:$LATEST",
      "Next": "DSS_TRANSACTION_DBO"
    },

    "DSS_TRANSACTION_DBO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-dss-transformation-dbo:$LATEST",
      "Next": "DSS_TRANSACTION_MASTER"
    },
    "DSS_TRANSACTION_MASTER": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-dss-transformation-master:$LATEST",
      "Next": "DSS_TRANSACTION_TRANSFORM"
    },
   "DSS_TRANSACTION_TRANSFORM": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-dss-transformation-transformation:$LATEST",
     "Next": "UPDATE_DSS_BI_TABLE"
    }
    ,
   "UPDATE_DSS_BI_TABLE": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-dss-transformation-update_bi:$LATEST",
      "Next": "UPDATE_DSS_BI_TABLE_1"
    }

    ,
   "UPDATE_DSS_BI_TABLE_1": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-dss-transformation-update_bi_1:$LATEST",
      "Next": "UPDATE_DSS_BI_TABLE_2"
    }

    ,
   "UPDATE_DSS_BI_TABLE_2": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-dss-transformation-update_bi_2:$LATEST",
      "Next": "UPDATE_DSS_BI_TABLE_3"
    }

    ,
   "UPDATE_DSS_BI_TABLE_3": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-dss-transformation-update_bi_3:$LATEST",
      "Next": "UPDATE_DSS_BI_TABLE_4"
    }


    ,
   "UPDATE_DSS_BI_TABLE_4": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-dss-transformation-update_bi_4:$LATEST",
     "End": true
    }

  }
}
EOF
}
