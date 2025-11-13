USE DBAdmin;
GO

EXEC dbadmin.usp_CaptureBaselineAll;
EXEC dbadmin.usp_CaptureHealthAll;
GO

SELECT TOP 10 * FROM dbadmin.InstanceBaseline ORDER BY Id DESC;
SELECT TOP 10 * FROM dbadmin.DatabaseBaseline ORDER BY Id DESC;
SELECT TOP 10 * FROM dbadmin.HealthFCI      ORDER BY Id DESC;
SELECT TOP 10 * FROM dbadmin.HealthHADR     ORDER BY Id DESC;
