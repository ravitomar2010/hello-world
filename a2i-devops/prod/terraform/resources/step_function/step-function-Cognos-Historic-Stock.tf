resource "aws_sfn_state_machine" "Cognos-Historic-Stock" {
  name     = "${var.platform}-Cognos-Historic-Stock"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "COGNOS HISTORIC STOCK",
  "StartAt": "HISTORIC_STOCK",
  "States": {
    "HISTORIC_STOCK": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-cognos_stock_date",
       "End": true
    }
  }
}
EOF
}
