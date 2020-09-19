resource "aws_sfn_state_machine" "cf-transformation" {
  name     = "${var.platform}-data-cf-transformation"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "CF Transaction Stage -> DBO",
  "StartAt": "CF_TRANSACTION_STAGE",
  "States": {
    "CF_TRANSACTION_STAGE": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cf-transformation-cf-stage:$LATEST",
      "Next": "CF_TRANSACTION_DBO"
    },

    "CF_TRANSACTION_DBO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cf-transformation-cf-dbo:$LATEST",
      "Next": "CF_TRANSACTION_MASTER"
    },
    "CF_TRANSACTION_MASTER": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cf-transformation-master:$LATEST",
       "Next": "CF_TRANSACTION_FACT"
    }
    ,
     "CF_TRANSACTION_FACT": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cf-transformation-cf-transformation:$LATEST",
       "Next": "CF_TRANSACTION_INVOICE"
    }

    ,
     "CF_TRANSACTION_INVOICE": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cf-transformation-update_invoice:$LATEST",
       "End": true
    }

  }
}
EOF
}
