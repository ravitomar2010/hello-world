resource "aws_sfn_state_machine" "data-demand-planning-forecasting" {
  name     = "${var.platform}-data-demand-planning-forecasting"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "Demand Forecasting Stage -> DBO",
  "StartAt": "STOCK_STAGE",
  "States": {
    "STOCK_STAGE": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-demand-planning-forecasting-stock-stage:$LATEST",
      "Next": "STOCK_DBO"
    },

    "STOCK_DBO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-demand-planning-forecasting-stock-dbo:$LATEST",
       "End": true
    }
  }
}
EOF
}
