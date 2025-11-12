/* Errorlog_LastN.sql */
EXEC master.dbo.xp_readerrorlog 0, 1, NULL, NULL, NULL, NULL, N'desc';
GO