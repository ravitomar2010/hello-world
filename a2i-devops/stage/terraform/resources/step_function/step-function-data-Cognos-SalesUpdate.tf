resource "aws_sfn_state_machine" "Cognos-SalesUpdate" {
  name     = "${var.platform}-ata-Cognos-SalesUpdate"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "COGNOS Sales Update -> STAGE-> DBO",
  "StartAt": "SALES_CF_TRANS_VIEWS",
  "States": {
    "SALES_CF_TRANS_VIEWS": {
       "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-sales_trans_cf",
      "Next": "SALES_ERP_TRANS_VIEWS"
    },


     "SALES_ERP_TRANS_VIEWS": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-sales_trans_erp",
     "Next": "SALES_ACTIVE_STAGE"
},

     "SALES_ACTIVE_STAGE": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-sales_active_stage",
       "Next": "SALES_ACTIVE_DBO"
},
        "SALES_ACTIVE_DBO": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-sales_active_dbo",
       "Next": "SALES_ERP_STAGE"
},
       "SALES_ERP_STAGE": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-sales_erp_stage",
       "Next": "SALES_ERP_DBO"

},

     "SALES_ERP_DBO": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-sales_erp_dbo",
       "Next": "COST"
},

    "COST": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-cognos_cost_fact",
       "Next": "SALES_ERP_POS_FACT"
},

        "SALES_ERP_POS_FACT": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-sales_erp_pos_fct",
       "Next": "FCT_SALES"

},

    "FCT_SALES": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-cognos_fct_sales",
       "End": true
        }
    }
}
EOF
}
