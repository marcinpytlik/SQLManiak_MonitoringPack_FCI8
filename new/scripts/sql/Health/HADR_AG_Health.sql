/* HADR_AG_Health.sql */
IF SERVERPROPERTY('IsHadrEnabled') = 1
BEGIN
    SELECT ag.name, ar.role_desc, ars.synchronization_health_desc, ar.replica_server_name
    FROM sys.availability_groups ag
    JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
    JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id;
END
ELSE SELECT 'HADR not enabled' AS info;
GO