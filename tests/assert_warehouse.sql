/* Executable acceptance criteria: each failure raises an error for sqlcmd -b.
   Unknown order dates and pre-1924 birthdates are retained per tutorial policy;
   see docs/replication_steps.md for the distinction from exploratory checks. */
SET NOCOUNT ON;
DECLARE @counts TABLE (object_name NVARCHAR(100), expected_rows BIGINT, actual_rows BIGINT);
INSERT INTO @counts VALUES
('silver.crm_cust_info', 18484, (SELECT COUNT_BIG(*) FROM silver.crm_cust_info)),
('silver.crm_prd_info', 397, (SELECT COUNT_BIG(*) FROM silver.crm_prd_info)),
('silver.crm_sales_details', 60398, (SELECT COUNT_BIG(*) FROM silver.crm_sales_details)),
('silver.erp_cust_az12', 18484, (SELECT COUNT_BIG(*) FROM silver.erp_cust_az12)),
('silver.erp_loc_a101', 18484, (SELECT COUNT_BIG(*) FROM silver.erp_loc_a101)),
('silver.erp_px_cat_g1v2', 37, (SELECT COUNT_BIG(*) FROM silver.erp_px_cat_g1v2)),
('gold.dim_customers', 18484, (SELECT COUNT_BIG(*) FROM gold.dim_customers)),
('gold.dim_products', 295, (SELECT COUNT_BIG(*) FROM gold.dim_products)),
('gold.fact_sales', 60398, (SELECT COUNT_BIG(*) FROM gold.fact_sales));
SELECT * FROM @counts ORDER BY object_name;
IF EXISTS (SELECT 1 FROM @counts WHERE actual_rows <> expected_rows)
    THROW 51101, 'FAIL warehouse: missing, duplicated or unexpected rows.', 1;

IF EXISTS (SELECT cst_id FROM silver.crm_cust_info GROUP BY cst_id HAVING COUNT(*) > 1 OR cst_id IS NULL)
    THROW 51102, 'FAIL Silver: invalid customer IDs.', 1;
IF EXISTS (
    SELECT cst_id, MAX(cst_create_date) AS latest_date
    FROM bronze.crm_cust_info WHERE cst_id IS NOT NULL GROUP BY cst_id
    EXCEPT SELECT cst_id, cst_create_date FROM silver.crm_cust_info
)
    THROW 51103, 'FAIL Silver: latest customer record not retained.', 1;
IF EXISTS (
    SELECT 1 FROM silver.crm_cust_info
    WHERE DATALENGTH(cst_firstname) <> DATALENGTH(TRIM(cst_firstname))
       OR DATALENGTH(cst_lastname) <> DATALENGTH(TRIM(cst_lastname))
       OR cst_gndr IS NULL OR cst_gndr NOT IN ('Male','Female','n/a')
       OR cst_marital_status IS NULL OR cst_marital_status NOT IN ('Single','Married','n/a')
)
    THROW 51104, 'FAIL Silver: customer standardization.', 1;
IF EXISTS (SELECT prd_id FROM silver.crm_prd_info GROUP BY prd_id HAVING COUNT(*) > 1 OR prd_id IS NULL)
    THROW 51105, 'FAIL Silver: invalid product IDs.', 1;
IF EXISTS (
    SELECT 1 FROM silver.crm_prd_info
    WHERE prd_cost IS NULL OR prd_cost < 0 OR prd_end_dt < prd_start_dt
       OR prd_line NOT IN ('Mountain','Road','Other Sales','Touring','n/a') OR prd_line IS NULL
)
    THROW 51106, 'FAIL Silver: product costs, validity or product lines.', 1;
IF EXISTS (
    SELECT 1 FROM silver.crm_sales_details
    WHERE sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
       OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
       OR sls_sales <> sls_quantity * sls_price
       OR sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt
)
    THROW 51107, 'FAIL Silver: sales arithmetic or date order.', 1;
IF EXISTS (
    SELECT 1 FROM silver.erp_cust_az12
    WHERE cid LIKE 'NAS%' OR bdate > GETDATE() OR gen IS NULL OR gen NOT IN ('Male','Female','n/a')
)
    THROW 51108, 'FAIL Silver: ERP customer normalization.', 1;
IF EXISTS (
    SELECT 1 FROM silver.erp_loc_a101
    WHERE cid LIKE '%-%' OR cntry IS NULL OR cntry IN ('','DE','US','USA')
       OR DATALENGTH(cntry) <> DATALENGTH(TRIM(cntry))
)
    THROW 51109, 'FAIL Silver: country normalization.', 1;
IF EXISTS (SELECT cid FROM silver.erp_cust_az12 GROUP BY cid HAVING COUNT(*) > 1 OR cid IS NULL)
 OR EXISTS (SELECT cid FROM silver.erp_loc_a101 GROUP BY cid HAVING COUNT(*) > 1 OR cid IS NULL)
 OR EXISTS (SELECT id FROM silver.erp_px_cat_g1v2 GROUP BY id HAVING COUNT(*) > 1 OR id IS NULL)
    THROW 51110, 'FAIL Silver: ERP join keys are not unique.', 1;
IF EXISTS (SELECT customer_id FROM gold.dim_customers GROUP BY customer_id HAVING COUNT(*) > 1 OR customer_id IS NULL)
 OR EXISTS (SELECT product_number FROM gold.dim_products GROUP BY product_number HAVING COUNT(*) > 1 OR product_number IS NULL)
    THROW 51111, 'FAIL Gold: joins duplicated business entities.', 1;
-- Aggregate the complete join; HASH JOIN avoids repeated evaluation of the
-- ROW_NUMBER views under a nested-loop/row-goal plan on the tutorial tables.
DECLARE @orphans BIGINT;
SELECT @orphans = COUNT_BIG(*)
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON f.customer_key = c.customer_key
LEFT JOIN gold.dim_products p ON f.product_key = p.product_key
WHERE c.customer_key IS NULL OR p.product_key IS NULL
OPTION (HASH JOIN);
IF @orphans <> 0
    THROW 51112, 'FAIL Gold: orphan sales.', 1;
IF (SELECT SUM(CAST(sales_amount AS BIGINT)) FROM gold.fact_sales)
 <> (SELECT SUM(CAST(sls_sales AS BIGINT)) FROM silver.crm_sales_details)
    THROW 51113, 'FAIL Gold: sales amount changed during integration.', 1;
-- Independently calculated from the versioned source sales records.
IF (SELECT SUM(CAST(sales_amount AS BIGINT)) FROM gold.fact_sales) <> 29356250
    THROW 51116, 'FAIL Gold: sales total differs from the source-derived baseline.', 1;
IF EXISTS (
    SELECT 1 FROM sys.columns c JOIN sys.views v ON c.object_id = v.object_id
    WHERE v.schema_id = SCHEMA_ID('gold') AND c.name IN ('customer_key','product_key')
      AND TYPE_NAME(c.user_type_id) <> 'bigint'
)
    THROW 51114, 'FAIL Gold: surrogate key data types differ from catalog.', 1;
IF (SELECT COUNT(*) FROM sys.views WHERE schema_id = SCHEMA_ID('gold')) <> 3
    THROW 51115, 'FAIL Gold: expected three views.', 1;
PRINT 'PASS Silver/Gold: counts, deduplication, normalization, amounts, keys and integration.';
GO
