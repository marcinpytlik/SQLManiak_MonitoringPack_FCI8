/* FCI_Health.sql */
SELECT SERVERPROPERTY('IsClustered') AS is_clustered,
       SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS active_node,
       SERVERPROPERTY('MachineName') AS machine_name,
       SERVERPROPERTY('ServerName') AS server_name;
GO
IF OBJECT_ID('sys.dm_os_cluster_nodes') IS NOT NULL SELECT * FROM sys.dm_os_cluster_nodes;
GO