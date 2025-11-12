/* Create_XE_SystemHealth_Clone.sql */
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'system_health_clone')
    DROP EVENT SESSION [system_health_clone] ON SERVER;
GO
CREATE EVENT SESSION [system_health_clone] ON SERVER
ADD EVENT sqlserver.error_reported(ACTION(sqlserver.sql_text,sqlserver.tsql_stack))
,ADD EVENT sqlserver.rpc_completed(ACTION(sqlserver.sql_text) WHERE (duration > 500000))
,ADD EVENT sqlserver.sql_batch_completed(ACTION(sqlserver.sql_text) WHERE (duration > 500000))
ADD TARGET package0.event_file (SET filename = N'system_health_clone', max_file_size=(50), max_rollover_files=(4))
WITH (MAX_MEMORY=4096 KB, EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS, MAX_DISPATCH_LATENCY=30 SECONDS, TRACK_CAUSALITY=ON, STARTUP_STATE=ON);
GO
ALTER EVENT SESSION [system_health_clone] ON SERVER STATE = START;
GO