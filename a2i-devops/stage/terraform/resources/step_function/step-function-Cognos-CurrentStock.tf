resource "aws_sfn_state_machine" "Cognos-CurrentStock" {
  name     = "${var.platform}-Cognos-CurrentStock"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "COGNOS Stock Stage -> DBO->Master",
  "StartAt": "STOCK_STAGE1",
  "States": {
    "STOCK_STAGE1": {
       "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-stock_stage1",
      "Next": "STOCK_STAGE2"
    },


     "STOCK_STAGE2": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-stock_stage2",
     "Next": "STOCK_DBO"
},

     "STOCK_DBO": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-stock_dbo",
       "Next": "STOCK_TRANSCTIONS"
},
        "STOCK_TRANSCTIONS": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-stock_trans_stg",
       "Next": "STOCK_FACT"
},
       "STOCK_FACT": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-cognos_stock_fact",
       "End": true

        }
    }
}
EOF
}
