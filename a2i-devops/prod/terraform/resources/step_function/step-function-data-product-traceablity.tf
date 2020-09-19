resource "aws_sfn_state_machine" "data-product-traceablity" {
  name     = "${var.platform}-data-product-traceablity"
  role_arn = "${var.aws_sfn_role_arn}"

  definition = <<EOF
{
  "Comment": "BI_PRODUCT_TRACEABILITY",
  "StartAt": "BI_PRODUCT_TRACEABILITY_DSS_SOURCE",
  "States": {
    "BI_PRODUCT_TRACEABILITY_DSS_SOURCE": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-DSS_INSERT:$LATEST",
      "Next": "BI_PRODUCT_TRACEABILITY_OTHER_SOURCE"
    }


    ,


    "BI_PRODUCT_TRACEABILITY_OTHER_SOURCE": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-SOURCE_INSERT:$LATEST",
       "Next": "BI_PRODUCT_TRACEABILITY_CVS"
    }



     ,


    "BI_PRODUCT_TRACEABILITY_CVS": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-CVS_INSERT:$LATEST",
       "Next": "BI_PRODUCT_TRACEABILITY_SHIPMENT"
    }



      ,


    "BI_PRODUCT_TRACEABILITY_SHIPMENT": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-SHIPMENT_INSERT:$LATEST",
       "Next": "BI_PRODUCT_TRACEABILITY_PUID"
    }


         ,


    "BI_PRODUCT_TRACEABILITY_PUID": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-PUID_MAP:$LATEST",
       "Next": "ACTIVATION_PUID"
    }
     ,

     "ACTIVATION_PUID": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-activation_nokia_huawei_puid:$LATEST",
       "Next": "BI_PRODUCT_TRACEABILITY_ACTIVATION"
    }
     ,


    "BI_PRODUCT_TRACEABILITY_ACTIVATION": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-ACTIVATION_INSERT:$LATEST",
       "Next": "BI_PRODUCT_TRACEABILITY_SUPPLIER"
    }


,


    "BI_PRODUCT_TRACEABILITY_SUPPLIER": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-SUPPLIER_MAP:$LATEST",
       "Next": "BI_PRODUCT_TRACEABILITY_RENAME"
    }

    ,


    "BI_PRODUCT_TRACEABILITY_RENAME": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-RENAME_WRK:$LATEST",
        "Next": "BI_EDI_1"
    }

    ,


    "BI_EDI_1": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-BI_EDI_1:$LATEST",
       "Next": "BI_EDI_2"
    }

    ,


    "BI_EDI_2": {
      "Type" : "Task",
      "Resource": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:axiom-telecom-a2i-data-imei-pool-BI_EDI_2:$LATEST",
        "End": true
    }


  }
}
EOF
}
