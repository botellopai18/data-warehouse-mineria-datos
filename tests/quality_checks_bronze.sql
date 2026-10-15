/* Counts exclude CSV headers and include the final record without a newline.
   Provenance and CSV column contracts: tests/source_manifest.json.
   These assertions apply to the six versioned tutorial files. */
SET NOCOUNT ON;
DECLARE @counts TABLE (source_file NVARCHAR(100), expected_rows BIGINT, actual_rows BIGINT);
INSERT INTO @counts VALUES
('CRM/cust_info.csv', 18494, (SELECT COUNT_BIG(*) FROM bronze.crm_cust_info)),
('CRM/prd_info.csv', 397, (SELECT COUNT_BIG(*) FROM bronze.crm_prd_info)),
('CRM/sales_details.csv', 60398, (SELECT COUNT_BIG(*) FROM bronze.crm_sales_details)),
('ERP/CUST_AZ12.csv', 18484, (SELECT COUNT_BIG(*) FROM bronze.erp_cust_az12)),
('ERP/LOC_A101.csv', 18484, (SELECT COUNT_BIG(*) FROM bronze.erp_loc_a101)),
('ERP/PX_CAT_G1V2.csv', 37, (SELECT COUNT_BIG(*) FROM bronze.erp_px_cat_g1v2));
SELECT * FROM @counts ORDER BY source_file;
IF EXISTS (SELECT 1 FROM @counts WHERE actual_rows <> expected_rows)
    THROW 51001, 'FAIL Bronze: CSV/SQL row count mismatch.', 1;

IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID('bronze')) <> 6
    THROW 51002, 'FAIL Bronze: expected six source tables.', 1;
IF (SELECT COUNT(*) FROM bronze.crm_cust_info WHERE cst_id IS NULL) <> 4
    THROW 51003, 'FAIL Bronze: source NULL customer identifiers were altered.', 1;
IF (SELECT COUNT(DISTINCT cst_id) FROM bronze.crm_cust_info) <> 18484
    THROW 51004, 'FAIL Bronze: source customer identifier contract.', 1;
IF EXISTS (
    SELECT 1 FROM sys.columns c
    WHERE c.object_id = OBJECT_ID('bronze.crm_sales_details')
      AND c.name IN ('sls_order_dt', 'sls_ship_dt', 'sls_due_dt')
      AND TYPE_NAME(c.user_type_id) <> 'int'
)
    THROW 51005, 'FAIL Bronze: raw dates must remain integers.', 1;
PRINT 'PASS Bronze: six source counts, raw identifiers and date schema.';
GO
