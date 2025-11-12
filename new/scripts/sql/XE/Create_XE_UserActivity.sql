/* Create_XE_UserActivity.sql */
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'user_activity')
    DROP EVENT SESSION [user_activity] ON SERVER;
GO
CREATE EVENT SESSION [user_activity] ON SERVER
ADD EVENT sqlserver.rpc_starting(ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.username,sqlserver.client_hostname,sqlserver.sql_text))
,ADD EVENT sqlserver.sql_batch_starting(ACTION(sqlserver.client_app_name,sqlserver.database_id,sqlserver.username,sqlserver.client_hostname,sqlserver.sql_text))
,ADD EVENT sqlserver.error_reported(ACTION(sqlserver.client_app_name,sqlserver.username,sqlserver.client_hostname,sqlserver.sql_text) WHERE ([severity]>10))
ADD TARGET package0.event_file(SET filename=N'user_activity', max_file_size=(50), max_rollover_files=(8))
WITH (MAX_MEMORY=4096 KB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY=5 SECONDS, TRACK_CAUSALITY=ON, STARTUP_STATE=OFF);
GO