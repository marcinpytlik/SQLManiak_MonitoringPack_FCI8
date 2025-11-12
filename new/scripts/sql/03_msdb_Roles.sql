/* 03_msdb_Roles.sql */
SET NOCOUNT ON;
USE [msdb];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'dbadmin')
    CREATE USER [dbadmin] FOR LOGIN [dbadmin];
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'SQLAgentReaderRole')
    ALTER ROLE [SQLAgentReaderRole] ADD MEMBER [dbadmin];
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'DatabaseMailUserRole')
    ALTER ROLE [DatabaseMailUserRole] ADD MEMBER [dbadmin];
GO