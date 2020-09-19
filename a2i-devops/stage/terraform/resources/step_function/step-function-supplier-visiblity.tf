resource "aws_sfn_state_machine" "supplier-visiblity" {
  name     = "${var.platform}-supplier-visiblity"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "SUPPLIER_VISIBILITY DEALER AND DISTRIBUTOR",
  "StartAt": "SELL_IN_CORE_TABLE",
  "States": {


    "SELL_IN_CORE_TABLE": {
       "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-sup-visiblity-Supplier_Visibility_Core",
      "Next": "DISTRIBUTOR_DOS"
    },


     "DISTRIBUTOR_DOS": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-sup-visiblity-DISTRIBUTOR_DOS",
     "Next": "DEALER_DOS_1"
},

     "DEALER_DOS_1": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-sup-visiblity-DEALER_DOS_1",
       "Next": "DEALER_DOS_2"
},
        "DEALER_DOS_2": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-sup-visiblity-DEALER_DOS_2",
       "Next": "DEALER_DOS_3"
},
       "DEALER_DOS_3": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-sup-visiblity-DEALER_DOS_3",
       "Next": "SUPPLY_CHAIN"

},

    "SUPPLY_CHAIN": {
       "Type" : "Task",
       "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-sup-visiblity-SUPPLY_CHAIN",
       "End": true
        }
    }
}
EOF
}
