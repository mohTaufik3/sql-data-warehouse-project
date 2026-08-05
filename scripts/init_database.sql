-- ============================================================
-- Create Data Warehouse Database and Layered Schemas
-- ============================================================

-- Switch to the system database to create the DataWarehouse database.
USE master;
GO

-- Create the main DataWarehouse database.
CREATE DATABASE DataWarehouse;
GO

-- Switch to the newly created DataWarehouse database.
USE DataWarehouse;
GO

-- Create the Bronze layer for storing raw and unprocessed data.
CREATE SCHEMA bronze;
GO

-- Create the Silver layer for storing cleaned and transformed data.
CREATE SCHEMA silver;
GO

-- Create the Gold layer for storing business-ready data
-- prepared for analytics, reporting, and visualization.
CREATE SCHEMA gold;
GO
