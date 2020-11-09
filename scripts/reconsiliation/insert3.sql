insert into om_dbo.OM_SALES_SERIAL (
select
			SOR_ID_SEQ          ::BIGINT,
			SOD_ID_SEQ          ::BIGINT,
			BUS_SEQ             ::integer,
			ORT_CODE            ::VARCHAR(30),
			SLS_STATUS          ::VARCHAR(30),
			cast(SLS_SCAN_DATE as timestamp) AS SLS_SCAN_DATE,
			SOR_ORDER_NO        ::VARCHAR(30),
			SOD_LINE_NO         ::BIGINT,
			SLS_ORDER_BARCODE           ::VARCHAR(300),
			ITM_SEQ             ::BIGINT,
			SLS_BASE_ITEM               ::varchar(30),
			SLS_ORDER_QUANTITY  ::smallint,
			SLS_SERAIL          ::VARCHAR(30),
			SLS_SERAIL2                 ::VARCHAR(30),
			SLS_SERAIL_CODE             ::VARCHAR(30),
			SLS_SCAN_COUNT      ::smallint,
			SLS_ITEM_CATEGORY           ::VARCHAR(30),
			SLS_ITEM_BRAND              ::VARCHAR(30),
			SLS_ITEM_MODEL              ::VARCHAR(50),
			SLS_ITEM_CODE               ::VARCHAR(100),
			SLS_IS_BASE_ITEM    ::VARCHAR(30),
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
			CREATE_MONTH ::smallint,
			CREATE_YEAR ::smallint,
			primary_key_om_sales_serial ::VARCHAR(1000),
			case when row_number() over(partition by primary_key_om_sales_serial order by UPDATED_DATE desc) = 1 then 'A'
			 else 'X' end as Active_flag from om_stage.OM_SALES_SERIAL_recon
			 where SOR_ORDER_NO in (select SOR_ORDER_NO from om_stage.om_sales_orders_recon_temp) and
  SOR_ORDER_NO not in (select SOR_ORDER_NO from om_dbo.OM_SALES_SERIAL ord));
