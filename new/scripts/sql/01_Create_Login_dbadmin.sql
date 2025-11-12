/* 01_Create_Login_dbadmin.sql */
SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'dbadmin')
BEGIN
    PRINT 'Creating SQL Login [dbadmin]...';
    CREATE LOGIN [dbadmin]
        WITH PASSWORD = 'ChangeMe_S3cure!#2025', CHECK_POLICY = ON, CHECK_EXPIRATION = ON;
END
ELSE PRINT 'Login [dbadmin] exists – skipping.';
GRANT VIEW SERVER STATE TO [dbadmin];
GRANT VIEW ANY DATABASE TO [dbadmin];
-- AD wariant (odkomentuj):  CREATE LOGIN [DOMAIN\dbadmin] FROM WINDOWS;
GO