/* Run from the repository root in SQLCMD mode; supply -v DataRoot="...".
   Refuse an existing database: this entry point is for a fresh installation. */
:on error exit
USE master;
GO
IF DB_ID(N'DataWarehouse') IS NOT NULL
    THROW 51000, 'DataWarehouse already exists. Use scripts/reload.sql to reload it without recreating the database.', 1;
GO
:r scripts/init_database.sql
:r scripts/bronze/ddl_bronze.sql
:r scripts/bronze/proc_load_bronze.sql
GO
EXEC bronze.load_bronze @data_root = N'$(DataRoot)';
GO
:r tests/quality_checks_bronze.sql
:r scripts/silver/ddl_silver.sql
:r scripts/silver/proc_load_silver.sql
GO
EXEC silver.load_silver;
GO
:r scripts/gold/ddl_gold.sql
:r tests/assert_warehouse.sql
