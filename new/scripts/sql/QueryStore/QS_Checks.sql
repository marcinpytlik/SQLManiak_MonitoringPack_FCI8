/* QS_Checks.sql */
SELECT db_name = d.name, qs.actual_state_desc, qs.desired_state_desc, qs.readonly_reason
FROM sys.databases d
LEFT JOIN sys.database_query_store_options qs ON d.database_id = qs.database_id
WHERE d.database_id > 4;
GO