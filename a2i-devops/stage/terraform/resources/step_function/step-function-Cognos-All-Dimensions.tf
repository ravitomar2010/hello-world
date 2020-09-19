resource "aws_sfn_state_machine" "Cognos-All-Dimensions" {
  name     = "${var.platform}-Cognos-All-Dimensions"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "COGNOS Dimension Stage -> DBO->Master",
  "StartAt": "STOCK_MASTER1",
  "States": {
    "STOCK_MASTER1": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-master_stock1",
       "Next": "STOCK_MASTER2"
    },

       "STOCK_MASTER2": {
          "Type" : "Task",
          "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-master_stock2",
          "Next": "SALES_MASTER1"
  },

       "SALES_MASTER1": {
         "Type" : "Task",
        "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-master_sales1",
        "Next": "SALES_MASTER2"
},

     "SALES_MASTER2": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-master_sales2",
       "Next": "DIMENSION"
},

       "DIMENSION": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-cognos_dim",
       "Next": "STAGE_TRUNCATE"
},

        "STAGE_TRUNCATE": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-truncate_stage",
       "End": true

        }
    }
}
EOF
}
