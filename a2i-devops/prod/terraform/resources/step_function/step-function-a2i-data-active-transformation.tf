resource "aws_sfn_state_machine" "data-active-transformation" {
  name     = "${var.platform}-data-active-transformation"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "ACTIVE ESTORE Transaction Stage -> DBO",
  "StartAt": "ESTORE_TRANSACTION_STAGE",
  "States": {
    "ESTORE_TRANSACTION_STAGE": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-active-transformation-estore_stage:$LATEST",
      "Next": "ESTORE_TRANSACTION_DBO"
    },

    "ESTORE_TRANSACTION_DBO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-active-transformation-estore_dbo:$LATEST",
       "Next": "ACTIVE_TRANSACTION_STAGE"
    }

    ,

    "ACTIVE_TRANSACTION_STAGE": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-active-transformation-active_stage:$LATEST",
       "Next": "ACTIVE_TRANSACTION_DBO"
    }

   ,

    "ACTIVE_TRANSACTION_DBO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-active-transformation-active_dbo:$LATEST",
       "Next": "ACTIVE_TRANSFER_BI"
    }
   ,
     "ACTIVE_TRANSFER_BI": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-active-transformation-act_transfer:$LATEST",
       "Next": "ACTIVE_TRANSACTION_BI"
    }
,

     "ACTIVE_TRANSACTION_BI": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-active-transformation-act_transaction:$LATEST",
       "Next": "ESTORE_TRANSFORMATION_BI"
    },
     "ESTORE_TRANSFORMATION_BI": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-active-transformation-estore_trans:$LATEST",
       "End": true
    }
  }
}
EOF
}
