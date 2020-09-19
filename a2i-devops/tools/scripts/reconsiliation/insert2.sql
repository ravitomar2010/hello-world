insert into om_dbo.OM_SALES_DETAIL (
select
			SOD_ID_SEQ             ::BIGINT,
			SOR_ID_SEQ             ::BIGINT,
			SOR_ORDER_NO           ::VARCHAR(30),
			SOD_LINE_NO            ::integer,
			SOD_LINE_STATUS        ::VARCHAR(30),
			SOD_UOM                ::VARCHAR(10),
			ITM_SEQ                ::BIGINT,
			SOD_ITEM_CODE          ::VARCHAR(100),
			SOD_ITEM_SOH           ::BIGINT,
			SOD_ITEM_COST                  ::decimal,
			SOD_ACTUAL_PRICE       ::decimal,
			SOD_ORDER_QUNATITY     ::BIGINT,
			PRP_SEQ                        ::BIGINT,
			SOD_PRICE_TAX_STATUS   ::VARCHAR(30),
			SOD_ITEM_PRICE         ::decimal,
			SOD_PRICE_DISCOUNT     ::decimal,
			SOD_LINE_DISCOUNT      ::decimal,
			SOD_ITEM_TAX_VALUE     ::decimal,
			SOD_ITEM_NET_VALUE     ::decimal,
			SOD_PROMO_VALUE                ::decimal,
			PMN_SEQ                        ::smallint,
			PMO_SEQ                        ::smallint,
			SOD_RECEIPT_PRICE              ::decimal,
			SOD_RECEIPT_DISCOUNT           ::decimal,
			SOD_RECEIPT_TAX                ::decimal,
			SOD_RECEIPT_VALUE              ::decimal,
			SOD_ITEM_CREDIT_DAYS           ::decimal,
			SOD_ITEM_PAYMENT_TERM          ::VARCHAR(30),
			SOD_ITEM_CREDIT_LIMIT  ::decimal,
			SOD_APPROVAL_REQUEST           ::VARCHAR(50),
			SOD_APPROVAL_STATUS            ::VARCHAR(30),
			SOD_CREDIT_REQUEST             ::decimal,
			SOD_REQUEST_STATUS             ::VARCHAR(30),
			SOD_ITEM_CATEGORY              ::VARCHAR(30),
			SOD_ITEM_BRAND                 ::VARCHAR(30),
			SOD_ITEM_MODEL                 ::VARCHAR(30),
			SOD_TAX_CODE                   ::VARCHAR(30),
			SOD_TAX_SUBCODE                ::VARCHAR(30),
			SOD_TAX_PERCENT                ::decimal,
			SOD_REFERENCE_NO               ::VARCHAR(30),
			SOD_BASE_ITEM                  ::smallint,
			SOD_MSL_FLAG                   ::VARCHAR(30),
			SO_FSL_FLAG                    ::VARCHAR(30),
			SOD_STOCK_TYPE                 ::VARCHAR(30),
			SOD_REASON_CODE                ::VARCHAR(300),
			SOD_CREDITNOTE_ISSUED          ::VARCHAR(30),
			SOD_PLN_SEQ                    ::smallint,
			SOD_BRAND_CL_USED              ::decimal,
			SOD_BRAND_CL_TYPE              ::VARCHAR(30),
			MDL_SEQ                        ::integer,
			cast(CREATED_DATE as timestamp) AS CREATED_DATE,
			CREATED_USER          ::smallint,
			cast(UPDATED_DATE as timestamp) AS UPDATED_DATE,
			UPDATED_USER           ::smallint,
			ATTRIBUTE1                     ::VARCHAR(100),
			ATTRIBUTE2                     ::VARCHAR(100),
			ATTRIBUTE3                     ::VARCHAR(100),
			ATTRIBUTE4                     ::VARCHAR(100),
			ATTRIBUTE5                     ::VARCHAR(100),
			ATTRIBUTE6                     ::VARCHAR(100),
			ATTRIBUTE7                     ::VARCHAR(100),
			ATTRIBUTE8                     ::VARCHAR(100),
			ATTRIBUTE9                     ::VARCHAR(100),
			ATTRIBUTE10                    ::VARCHAR(100),
			ATTRIBUTE11                    ::VARCHAR(100),
			ATTRIBUTE12                    ::VARCHAR(100),
			ATTRIBUTE13                    ::VARCHAR(100),
			ATTRIBUTE14                    ::VARCHAR(100),
			ATTRIBUTE15                    ::VARCHAR(130),
			CREATE_MONTH ::smallint,
			CREATE_YEAR ::smallint,
			case when row_number() over(partition by SOD_ID_SEQ order by UPDATED_DATE desc) = 1 then 'A'
			else 'X' end as Active_flag from om_stage.OM_SALES_DETAIL_recon
			where SOR_ORDER_NO in (select SOR_ORDER_NO from om_stage.om_sales_orders_recon_temp)  and
  SOR_ORDER_NO not in (select SOR_ORDER_NO from om_dbo.OM_SALES_DETAIL ord));