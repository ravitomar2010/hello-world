resource "aws_sfn_state_machine" "Cognos-Purchase" {
  name     = "${var.platform}-Cognos-Purchase"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "COGNOS PURCHASE",
  "StartAt": "PO-GRN-MASTER",
  "States": {
    "PO-GRN-MASTER": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-po_grn_master",
       "Next": "PO-GRN-STAGE"
    },

       "PO-GRN-STAGE": {
          "Type" : "Task",
          "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-po_grn_stage",
          "Next": "PO-GRN-DBO"
  },

       "PO-GRN-DBO": {
         "Type" : "Task",
        "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-po_grn_dbo",
        "Next": "FCT_PURCHASE"
  },

        "FCT_PURCHASE": {
         "Type" : "Task",
        "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-cognos-transformation-cognos_fct_purchase",
        "End": true

        }
    }
}
EOF
}
