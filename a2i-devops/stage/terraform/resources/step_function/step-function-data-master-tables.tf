resource "aws_sfn_state_machine" "data-master-tables" {
  name     = "${var.platform}-data-master-tables"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "AXIOM MASTER",
  "StartAt": "ERP_MASTER",
  "States": {
    "ERP_MASTER": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-master:$LATEST",
      "Next": "ACTIVE_MASTER"
    },

    "ACTIVE_MASTER": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-active-transformation-active_master:$LATEST",
      "Next": "ESTORE_MASTER"
    },
    "ESTORE_MASTER": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-active-transformation-estore_master:$LATEST",
       "End": true
    }



  }
}
EOF
}
