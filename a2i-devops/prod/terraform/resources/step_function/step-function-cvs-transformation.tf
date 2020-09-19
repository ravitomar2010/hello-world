resource "aws_sfn_state_machine" "cvs-transformation" {
  name     = "${var.platform}-data-cvs-transformation"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "CVS Transaction Stage -> DBO",
  "StartAt": "CVS_TRANSACTION_STAGE",
  "States": {
    "CVS_TRANSACTION_STAGE": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cf-transformation-cvs-stage:$LATEST",
      "Next": "CVS_TRANSACTION_DBO"
    },

    "CVS_TRANSACTION_DBO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cf-transformation-cvs-dbo:$LATEST",
       "Next": "CVS_TRANSACTION_FACT"
    }
    ,
      "CVS_TRANSACTION_FACT": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cf-transformation-cvs-transformation:$LATEST",
       "End": true
    }
  }
}
EOF
}
