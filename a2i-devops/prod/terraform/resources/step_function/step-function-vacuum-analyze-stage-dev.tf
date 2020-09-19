resource "aws_sfn_state_machine" "vacuum-analyze-stage-dev" {
  name     = "${var.platform}-data-vacuum-analyze-stage-dev"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "VACUUM-ANALYZE-SPACE-STAGE -> VACUUM-ANALYZE-SPACE-STAGE",
  "StartAt": "VACUUM-ANALYZE-SPACE-STAGE",
  "States": {
    "VACUUM-ANALYZE-SPACE-STAGE": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-sys-management-vacuum_analyze:$LATEST",
      "Next": "VACUUM-ANALYZE-SPACE-STAGE-OM"
    }

	    ,
      "VACUUM-ANALYZE-SPACE-STAGE-OM": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-sys-management-om_vacuum_analyze:$LATEST",
       "Next": "VACUUM-ANALYZE-SPACE-STAGE-DSS"
    },
	    "VACUUM-ANALYZE-SPACE-STAGE-DSS": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-sys-management-dss_vacuum_analyze:$LATEST",
       "Next": "VACUUM-ANALYZE-SPACE-STAGE-CVS"
    }
	    ,
      "VACUUM-ANALYZE-SPACE-STAGE-CVS": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-sys-management-cvs_vacuum_analyze:$LATEST",
       "Next": "VACUUM-ANALYZE-SPACE-STAGE-CF"
    }
	    ,
    "VACUUM-ANALYZE-SPACE-STAGE-CF": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-sys-management-cf_vacuum_analyze:$LATEST",
       "Next": "VACUUM-ANALYZE-SPACE-STAGE-ERP"
    }
	    ,
     "VACUUM-ANALYZE-SPACE-STAGE-ERP": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-sys-management-erp_vacuum_analyze:$LATEST",
       "End": true
    }
  }
}
EOF
}
