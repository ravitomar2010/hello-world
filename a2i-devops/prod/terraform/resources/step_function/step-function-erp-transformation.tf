resource "aws_sfn_state_machine" "erp-transformation" {
  name     = "${var.platform}-data-erp-transformation"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "ERP Transaction Stage -> DBO->Master",
  "StartAt": "ERP_TRANSACTION_RCV_STAGE",
  "States": {
    "ERP_TRANSACTION_RCV_STAGE": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-erp_RCV_stage:$LATEST",
      "Next": "ERP_TRANSACTION_RCV_DBO"
    },

    "ERP_TRANSACTION_RCV_DBO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-erp_RCV_dbo:$LATEST",
       "Next": "ERP_TRANSACTION_PO_STAGE"
    }
    ,

	 "ERP_TRANSACTION_PO_STAGE": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-erp_PO_stage:$LATEST",
      "Next": "ERP_TRANSACTION_PO_DBO"
    },

    "ERP_TRANSACTION_PO_DBO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-erp_PO_dbo:$LATEST",
       "Next": "ERP_TRANSACTION_OE_STAGE"
    }

	 ,

	 "ERP_TRANSACTION_OE_STAGE": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-erp_OE_stage:$LATEST",
      "Next": "ERP_TRANSACTION_OE_DBO"
    },

    "ERP_TRANSACTION_OE_DBO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-erp_OE_dbo:$LATEST",
       "Next": "ERP_TRANSACTION_MTL_STAGE"
    }

	 ,

	 "ERP_TRANSACTION_MTL_STAGE": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-erp_MTL_stage:$LATEST",
      "Next": "ERP_TRANSACTION_MTL_DBO"
    },

    "ERP_TRANSACTION_MTL_DBO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-erp_MTL_dbo:$LATEST",
       "Next": "ERP_TRANSACTION_RA_STAGE"
    }

	,

	 "ERP_TRANSACTION_RA_STAGE": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-erp_RA_stage:$LATEST",
      "Next": "ERP_TRANSACTION_RA_DBO"
    },

    "ERP_TRANSACTION_RA_DBO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-erp_RA_dbo:$LATEST",
        "Next": "ERP_TRANSFORMATION_PO"
    }

	,

    "ERP_TRANSFORMATION_PO": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-po:$LATEST",
        "Next": "ERP_TRANSFORMATION_ORDER"
    }

	,

    "ERP_TRANSFORMATION_ORDER": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-order:$LATEST",
        "Next": "ERP_TRANSFORMATION_SHIPMENT"
    }



		,

    "ERP_TRANSFORMATION_SHIPMENT": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-shipment:$LATEST",
        "Next": "ERP_TRANSFORMATION_MOVEMENT"
    }

		,

    "ERP_TRANSFORMATION_MOVEMENT": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-movement:$LATEST",
        "Next": "ERP_TRANSFORMATION_CUSTOMER"
    }
	,
	  "ERP_TRANSFORMATION_CUSTOMER": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-customer:$LATEST",
        "Next": "ERP_STAGE_TRUNCATE"
    }

    ,
	  "ERP_STAGE_TRUNCATE": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-erp-transformation-truncate_stage:$LATEST",
        "End": true
    }

  }
}
EOF
}
