resource "aws_sfn_state_machine" "vacuum-analyze-dev" {
  name     = "${var.platform}-data-vacuum-analyze-dev"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "VACUUM-ANALYZE-SPACE-DEV",
  "StartAt": "VACUUM-ANALYZE-SPACE-DEV",
  "States": {
      "VACUUM-ANALYZE-SPACE-DEV": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-sys-management-vacuum_analyze:$LATEST",
       "Next": "VACUUM-ANALYZE-SPACE-DEV-OM"
    }

	    ,
      "VACUUM-ANALYZE-SPACE-DEV-OM": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-sys-management-om_vacuum_analyze:$LATEST",
       "Next": "VACUUM-ANALYZE-SPACE-DEV-DSS"
    },
	    "VACUUM-ANALYZE-SPACE-DEV-DSS": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-sys-management-dss_vacuum_analyze:$LATEST",
       "Next": "VACUUM-ANALYZE-SPACE-DEV-CVS"
    }
	    ,
      "VACUUM-ANALYZE-SPACE-DEV-CVS": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-sys-management-cvs_vacuum_analyze:$LATEST",
       "Next": "VACUUM-ANALYZE-SPACE-DEV-CF"
    }
	    ,
    "VACUUM-ANALYZE-SPACE-DEV-CF": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-sys-management-cf_vacuum_analyze:$LATEST",
       "Next": "VACUUM-ANALYZE-SPACE-DEV-ERP"
    }
	    ,
     "VACUUM-ANALYZE-SPACE-DEV-ERP": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:developer-a2i-data-sys-management-erp_vacuum_analyze:$LATEST",
       "End": true
    }
  }
}
EOF
}
