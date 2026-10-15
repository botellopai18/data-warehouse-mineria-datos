/* Full reload of an already installed warehouse; no database/schema DDL. */
:on error exit
USE DataWarehouse;
GO
EXEC bronze.load_bronze @data_root = N'$(DataRoot)';
GO
:r tests/quality_checks_bronze.sql
EXEC silver.load_silver;
GO
:r tests/assert_warehouse.sql
