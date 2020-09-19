resource "aws_sfn_state_machine" "data-edi-transformation" {
  name     = "${var.platform}-data-edi-transformation"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "EDI Transformation and SO/SR tables",
  "StartAt": "EDI_POOL",
  "States": {
    "EDI_POOL": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-edi-transformation-edi_imei_pool:$LATEST",
        "End": true
                }
            }
}
EOF
}
