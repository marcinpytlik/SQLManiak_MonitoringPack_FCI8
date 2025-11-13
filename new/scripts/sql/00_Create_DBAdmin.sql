/* 00_Create_DBAdmin.sql – SQL Server 2022 */
SET NOCOUNT ON;
IF DB_ID(N'DBAdmin') IS NULL
BEGIN
    PRINT 'Creating database [DBAdmin]...';
    DECLARE @data NVARCHAR(260) = (SELECT physical_name FROM sys.database_files WHERE name = 'master' AND file_id = 1);
    DECLARE @log  NVARCHAR(260) = (SELECT physical_name FROM sys.database_files WHERE name = 'mastlog' AND file_id = 2);
    DECLARE @dataDir NVARCHAR(260) = LEFT(@data, LEN(@data) - CHARINDEX('\', REVERSE(@data)) + 1);
    DECLARE @logDir  NVARCHAR(260) = LEFT(@log , LEN(@log ) - CHARINDEX('\', REVERSE(@log )) + 1);
    DECLARE @sql NVARCHAR(MAX) = N'
    CREATE DATABASE [DBAdmin]
    ON PRIMARY ( NAME = N''DBAdmin'', FILENAME = N''' + @dataDir + 'DBAdmin.mdf' + ''', SIZE = 128MB, FILEGROWTH = 64MB )
    LOG ON    ( NAME = N''DBAdmin_log'', FILENAME = N''' + @logDir + 'DBAdmin_log.ldf' + ''', SIZE = 128MB, FILEGROWTH = 64MB );';
    EXEC (@sql);
END
ELSE PRINT 'Database [DBAdmin] already exists – skipping.';
GO
