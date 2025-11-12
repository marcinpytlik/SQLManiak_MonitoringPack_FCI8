/* QS_TopRegressions.sql */
IF DB_ID() IN (1,2,3,4) BEGIN RAISERROR('Uruchom w kontekście bazy użytkownika.',16,1); RETURN; END;
SELECT TOP (20)
    qsq.query_id, p.plan_id, rs1.avg_duration AS avg_duration_prev, rs2.avg_duration AS avg_duration_curr,
    (rs2.avg_duration - rs1.avg_duration) AS delta_duration,
    TRY_CONVERT(xml, qsq.query_sql_text) AS query_text
FROM sys.query_store_query_text AS qsq
JOIN sys.query_store_query AS qsqry ON qsq.query_text_id = qsqry.query_text_id
JOIN sys.query_store_plan AS p ON p.query_id = qsqry.query_id
JOIN sys.query_store_runtime_stats AS rs2 ON rs2.plan_id = p.plan_id
JOIN sys.query_store_runtime_stats_interval AS rsi2 ON rsi2.runtime_stats_interval_id = rs2.runtime_stats_interval_id
JOIN sys.query_store_runtime_stats AS rs1 ON rs1.plan_id = p.plan_id AND rs1.runtime_stats_interval_id = rs2.runtime_stats_interval_id - 1
WHERE rs1.avg_duration IS NOT NULL AND rs2.avg_duration IS NOT NULL
ORDER BY delta_duration DESC;
GO