/* Integration tests on the disposable verification database only.
   Compare ordered full-row hashes, not just totals. Multiplicity and NULLs
   participate in the hash. Technical load timestamps are ignored ONLY for
   the successful reload; rollback tests include them. */
SET NOCOUNT ON;
CREATE TABLE #snapshots (
    phase VARCHAR(30), object_name NVARCHAR(260), rows_count BIGINT, digest VARBINARY(32)
);
GO
CREATE PROCEDURE #capture_snapshot @phase VARCHAR(30), @include_metadata BIT AS
BEGIN
    DECLARE @object NVARCHAR(260), @columns NVARCHAR(MAX), @sql NVARCHAR(MAX);
    DECLARE objects CURSOR LOCAL FAST_FORWARD FOR
        SELECT QUOTENAME(s.name) + '.' + QUOTENAME(o.name),
               STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(c.name)), ',') WITHIN GROUP (ORDER BY c.column_id)
        FROM sys.objects o JOIN sys.schemas s ON o.schema_id = s.schema_id
        JOIN sys.columns c ON c.object_id = o.object_id
        WHERE s.name IN ('bronze','silver','gold') AND o.type IN ('U','V')
          AND (@include_metadata = 1 OR c.name <> 'dwh_create_date')
        GROUP BY s.name, o.name;
    OPEN objects;
    FETCH NEXT FROM objects INTO @object, @columns;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'INSERT INTO #snapshots SELECT @phase, @object, COUNT_BIG(*), '
            + N'HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), (SELECT ' + @columns
            + N' FROM ' + @object + N' ORDER BY ' + @columns
            + N' FOR JSON PATH, INCLUDE_NULL_VALUES))) FROM ' + @object + N';';
        EXEC sys.sp_executesql @sql, N'@phase VARCHAR(30), @object NVARCHAR(260)', @phase, @object;
        FETCH NEXT FROM objects INTO @object, @columns;
    END;
    CLOSE objects;
    DEALLOCATE objects;
END;
GO
EXEC #capture_snapshot 'initial', 0;
EXEC bronze.load_bronze @data_root = N'$(DataRoot)';
EXEC silver.load_silver;
EXEC #capture_snapshot 'reloaded', 0;
IF EXISTS (
    SELECT object_name, rows_count, digest FROM #snapshots WHERE phase = 'initial'
    EXCEPT SELECT object_name, rows_count, digest FROM #snapshots WHERE phase = 'reloaded'
) OR (SELECT COUNT(*) FROM #snapshots WHERE phase = 'reloaded') <> 15
    THROW 51201, 'FAIL: full reload changed business data.', 1;
PRINT 'PASS reload: identical ordered row hashes across all 15 objects.';
GO
EXEC #capture_snapshot 'before_failure', 1;
DECLARE @caught BIT = 0;
BEGIN TRY
    EXEC bronze.load_bronze @data_root = N'/__dwh_missing_directory__/datasets';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (4860, 4861) THROW;
    SET @caught = 1;
END CATCH;
IF @caught = 0 THROW 51202, 'FAIL: missing CSV did not propagate an error.', 1;
EXEC #capture_snapshot 'bronze_rollback', 1;
IF EXISTS (
    SELECT object_name, rows_count, digest FROM #snapshots WHERE phase = 'before_failure'
    EXCEPT SELECT object_name, rows_count, digest FROM #snapshots WHERE phase = 'bronze_rollback'
)
    THROW 51203, 'FAIL: Bronze failure changed persisted data.', 1;
PRINT 'PASS Bronze failure: missing CSV error propagated; all rows restored.';
GO
-- The tutorial deliberately retains CAST date semantics. Invalid 8-digit
-- dates must fail explicitly, and the improved transaction must roll back.
INSERT INTO bronze.crm_sales_details
    (sls_ord_num,sls_prd_key,sls_cust_id,sls_order_dt,sls_ship_dt,sls_due_dt,sls_sales,sls_quantity,sls_price)
VALUES ('__VERIFY_INVALID_DATE__','TEST',11000,20250230,20250301,20250302,10,1,10);
DECLARE @caught BIT = 0;
BEGIN TRY
    EXEC silver.load_silver;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 241 THROW;
    SET @caught = 1;
END CATCH;
DELETE FROM bronze.crm_sales_details WHERE sls_ord_num = '__VERIFY_INVALID_DATE__';
IF @caught = 0 THROW 51204, 'FAIL: impossible date did not propagate an error.', 1;
EXEC #capture_snapshot 'silver_rollback', 1;
IF EXISTS (
    SELECT object_name, rows_count, digest FROM #snapshots WHERE phase = 'before_failure'
    EXCEPT SELECT object_name, rows_count, digest FROM #snapshots WHERE phase = 'silver_rollback'
)
    THROW 51205, 'FAIL: Silver failure changed persisted data or load timestamps.', 1;
PRINT 'PASS Silver failure: conversion error propagated; all rows and timestamps restored.';
SELECT phase, object_name, rows_count, CONVERT(VARCHAR(64), digest, 2) AS sha256
FROM #snapshots ORDER BY phase, object_name;
GO
:r tests/quality_checks_bronze.sql
:r tests/assert_warehouse.sql
