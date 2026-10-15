/* Aggregated before/after evidence. No customer names or personal rows. */
SET NOCOUNT ON;
SELECT 'customer_rows' AS metric,
 (SELECT COUNT(*) FROM bronze.crm_cust_info) AS bronze_value,
 (SELECT COUNT(*) FROM silver.crm_cust_info) AS silver_value
UNION ALL SELECT 'null_customer_ids',
 (SELECT COUNT(*) FROM bronze.crm_cust_info WHERE cst_id IS NULL),
 (SELECT COUNT(*) FROM silver.crm_cust_info WHERE cst_id IS NULL)
UNION ALL SELECT 'excess_duplicate_customer_ids',
 (SELECT COUNT(cst_id)-COUNT(DISTINCT cst_id) FROM bronze.crm_cust_info),
 (SELECT COUNT(cst_id)-COUNT(DISTINCT cst_id) FROM silver.crm_cust_info)
UNION ALL SELECT 'names_with_outer_spaces',
 (SELECT COUNT(*) FROM bronze.crm_cust_info WHERE DATALENGTH(cst_firstname) <> DATALENGTH(TRIM(cst_firstname)) OR DATALENGTH(cst_lastname) <> DATALENGTH(TRIM(cst_lastname))),
 (SELECT COUNT(*) FROM silver.crm_cust_info WHERE DATALENGTH(cst_firstname) <> DATALENGTH(TRIM(cst_firstname)) OR DATALENGTH(cst_lastname) <> DATALENGTH(TRIM(cst_lastname)))
UNION ALL SELECT 'invalid_sales_arithmetic',
 (SELECT COUNT(*) FROM bronze.crm_sales_details WHERE sls_sales <> sls_quantity*sls_price OR sls_sales IS NULL OR sls_price IS NULL OR sls_price <= 0 OR sls_sales <= 0),
 (SELECT COUNT(*) FROM silver.crm_sales_details WHERE sls_sales <> sls_quantity*sls_price OR sls_sales IS NULL OR sls_price IS NULL OR sls_price <= 0 OR sls_sales <= 0)
UNION ALL SELECT 'future_birthdates',
 (SELECT COUNT(*) FROM bronze.erp_cust_az12 WHERE bdate > GETDATE()),
 (SELECT COUNT(*) FROM silver.erp_cust_az12 WHERE bdate > GETDATE());

SELECT 'unknown_order_dates' AS retained_condition, COUNT(*) AS rows_count
FROM silver.crm_sales_details WHERE sls_order_dt IS NULL
UNION ALL SELECT 'birthdates_before_1924', COUNT(*)
FROM silver.erp_cust_az12 WHERE bdate < '19240101';
SELECT COUNT_BIG(*) AS sales_rows, SUM(CAST(sales_amount AS BIGINT)) AS total_sales,
 SUM(CAST(quantity AS BIGINT)) AS total_quantity FROM gold.fact_sales;
GO
