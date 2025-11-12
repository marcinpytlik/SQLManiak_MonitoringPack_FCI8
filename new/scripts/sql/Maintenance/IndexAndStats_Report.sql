/* IndexAndStats_Report.sql */
SELECT DB_NAME() AS db_name, o.name AS object_name, i.name AS index_name, ps.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') ps
JOIN sys.indexes i ON ps.object_id = i.object_id AND ps.index_id = i.index_id
JOIN sys.objects o ON o.object_id = i.object_id
WHERE o.type = 'U'
ORDER BY ps.avg_fragmentation_in_percent DESC;
GO
SELECT name AS stat_name, auto_created, user_created, no_recompute, has_filter
FROM sys.stats WHERE object_id IN (SELECT object_id FROM sys.objects WHERE type='U');
GO