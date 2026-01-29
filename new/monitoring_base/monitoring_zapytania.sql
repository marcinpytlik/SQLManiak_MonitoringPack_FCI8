/* ==========================================================
   BASELINE DELTA – MASTER QUERY
   Porównuje dwa run_id (BEFORE/AFTER) i zwraca resultsety:
   0) Meta runs
   1) Waits delta
   2) File IO delta
   3) Perf counters delta
   4) Memory clerks delta
   5) Per-DB sizes delta
   6) VLF delta
   7) Log reuse wait (zmiany)
   8) Scheduler health delta
   9) XE spikes summary + latest events (RunB)
   10) Top queries delta (dm_exec_query_stats snapshot)
   11) New top queries in RunB
   ========================================================== */

DECLARE @runA uniqueidentifier = '864A0593-195B-4181-95ED-2FC916206F73'; -- BEFORE
DECLARE @runB uniqueidentifier = '864A0593-195B-4181-95ED-2FC916206F73'; -- AFTER
DECLARE @TopN int = 30;

------------------------------------------------------------
-- 0) META: informacje o pomiarach
------------------------------------------------------------
SELECT
  'RunA' AS run_label, r.run_id, r.capture_utc, r.capture_local, r.server_name,
  r.instance_name, r.sql_version, r.edition, r.notes
FROM DBA_tools.baseline.Run r
WHERE r.run_id = @runA;

SELECT
  'RunB' AS run_label, r.run_id, r.capture_utc, r.capture_local, r.server_name,
  r.instance_name, r.sql_version, r.edition, r.notes
FROM DBA_tools.baseline.Run r
WHERE r.run_id = @runB;

------------------------------------------------------------
-- 1) WAITS: Top delta
------------------------------------------------------------
;WITH a AS
(
  SELECT wait_type, wait_time_ms, signal_wait_time_ms, waiting_tasks_count
  FROM DBA_tools.baseline.WaitStats WHERE run_id = @runA
),
b AS
(
  SELECT wait_type, wait_time_ms, signal_wait_time_ms, waiting_tasks_count
  FROM DBA_tools.baseline.WaitStats WHERE run_id = @runB
)
SELECT TOP (@TopN)
  COALESCE(b.wait_type, a.wait_type) AS wait_type,
  ISNULL(a.wait_time_ms,0) AS wait_ms_A,
  ISNULL(b.wait_time_ms,0) AS wait_ms_B,
  ISNULL(b.wait_time_ms,0)-ISNULL(a.wait_time_ms,0) AS delta_wait_ms,
  ISNULL(a.signal_wait_time_ms,0) AS signal_ms_A,
  ISNULL(b.signal_wait_time_ms,0) AS signal_ms_B,
  ISNULL(b.signal_wait_time_ms,0)-ISNULL(a.signal_wait_time_ms,0) AS delta_signal_ms,
  ISNULL(a.waiting_tasks_count,0) AS tasks_A,
  ISNULL(b.waiting_tasks_count,0) AS tasks_B,
  ISNULL(b.waiting_tasks_count,0)-ISNULL(a.waiting_tasks_count,0) AS delta_tasks
FROM a
FULL JOIN b ON b.wait_type = a.wait_type
ORDER BY delta_wait_ms DESC;

------------------------------------------------------------
-- 2) FILE IO: delta stalls / ops
------------------------------------------------------------
SELECT TOP (@TopN)
  DB_NAME(b.database_id) AS db_name,
  b.file_logical_name,
  b.file_physical_name,
  (b.io_stall_read_ms  - a.io_stall_read_ms)  AS delta_read_stall_ms,
  (b.io_stall_write_ms - a.io_stall_write_ms) AS delta_write_stall_ms,
  (b.num_of_reads      - a.num_of_reads)      AS delta_reads,
  (b.num_of_writes     - a.num_of_writes)     AS delta_writes,
  (b.size_on_disk_bytes - a.size_on_disk_bytes) AS delta_size_bytes
FROM DBA_tools.baseline.FileIO a
JOIN DBA_tools.baseline.FileIO b
  ON b.database_id = a.database_id AND b.file_id = a.file_id
WHERE a.run_id = @runA AND b.run_id = @runB
ORDER BY (b.io_stall_write_ms - a.io_stall_write_ms) DESC;

------------------------------------------------------------
-- 3) PERF COUNTERS: delta values
------------------------------------------------------------
SELECT TOP (@TopN)
  b.object_name, b.counter_name, b.instance_name,
  a.cntr_value AS value_A,
  b.cntr_value AS value_B,
  (b.cntr_value - a.cntr_value) AS delta_value,
  b.cntr_type
FROM DBA_tools.baseline.PerfCounters a
JOIN DBA_tools.baseline.PerfCounters b
  ON b.object_name = a.object_name
 AND b.counter_name = a.counter_name
 AND b.instance_name = a.instance_name
WHERE a.run_id = @runA AND b.run_id = @runB
ORDER BY ABS(b.cntr_value - a.cntr_value) DESC;

------------------------------------------------------------
-- 4) MEMORY CLERKS: delta
------------------------------------------------------------
SELECT TOP (@TopN)
  COALESCE(b.clerk_name, a.clerk_name) AS clerk_name,
  ISNULL(a.pages_kb,0) AS pages_kb_A,
  ISNULL(b.pages_kb,0) AS pages_kb_B,
  ISNULL(b.pages_kb,0) - ISNULL(a.pages_kb,0) AS delta_pages_kb,
  ISNULL(a.virtual_mem_kb,0) AS vmem_kb_A,
  ISNULL(b.virtual_mem_kb,0) AS vmem_kb_B,
  ISNULL(b.virtual_mem_kb,0) - ISNULL(a.virtual_mem_kb,0) AS delta_vmem_kb
FROM DBA_tools.baseline.MemoryClerks a
FULL JOIN DBA_tools.baseline.MemoryClerks b
  ON b.clerk_name = a.clerk_name
 AND b.run_id = @runB
WHERE a.run_id = @runA OR a.run_id IS NULL
ORDER BY delta_pages_kb DESC;

------------------------------------------------------------
-- 5) PER-DB SIZES: data/log delta
------------------------------------------------------------
SELECT TOP (@TopN)
  b.db_name,
  a.data_size_mb AS data_mb_A, b.data_size_mb AS data_mb_B, (b.data_size_mb - a.data_size_mb) AS delta_data_mb,
  a.log_size_mb  AS log_mb_A,  b.log_size_mb  AS log_mb_B,  (b.log_size_mb  - a.log_size_mb)  AS delta_log_mb,
  a.total_size_mb AS total_mb_A, b.total_size_mb AS total_mb_B, (b.total_size_mb - a.total_size_mb) AS delta_total_mb
FROM DBA_tools.baseline.DbSizes a
JOIN DBA_tools.baseline.DbSizes b
  ON b.database_id = a.database_id
WHERE a.run_id = @runA AND b.run_id = @runB
ORDER BY (b.total_size_mb - a.total_size_mb) DESC;

------------------------------------------------------------
-- 6) VLF: delta
------------------------------------------------------------
SELECT TOP (@TopN)
  b.db_name,
  a.vlf_count AS vlf_A, b.vlf_count AS vlf_B, (b.vlf_count - a.vlf_count) AS delta_vlf,
  a.active_vlfs AS active_A, b.active_vlfs AS active_B, (b.active_vlfs - a.active_vlfs) AS delta_active,
  a.total_log_mb AS log_mb_A, b.total_log_mb AS log_mb_B, (b.total_log_mb - a.total_log_mb) AS delta_log_mb
FROM DBA_tools.baseline.DbVLF a
JOIN DBA_tools.baseline.DbVLF b
  ON b.database_id = a.database_id
WHERE a.run_id = @runA AND b.run_id = @runB
ORDER BY (b.vlf_count - a.vlf_count) DESC;

------------------------------------------------------------
-- 7) LOG REUSE WAIT: zmiany / co blokuje log
------------------------------------------------------------
SELECT
  b.db_name,
  a.log_reuse_wait_desc AS reuse_A,
  b.log_reuse_wait_desc AS reuse_B,
  CASE WHEN a.log_reuse_wait_desc <> b.log_reuse_wait_desc THEN 1 ELSE 0 END AS changed
FROM DBA_tools.baseline.DbLogReuse a
JOIN DBA_tools.baseline.DbLogReuse b
  ON b.database_id = a.database_id
WHERE a.run_id = @runA AND b.run_id = @runB
  AND (a.log_reuse_wait_desc <> b.log_reuse_wait_desc OR b.log_reuse_wait_desc <> N'NOTHING')
ORDER BY changed DESC, b.db_name;

------------------------------------------------------------
-- 8) SCHEDULER HEALTH: delta runnable/workq/load
------------------------------------------------------------
SELECT TOP (@TopN)
  b.scheduler_id,
  a.runnable_tasks_count AS runnable_A,
  b.runnable_tasks_count AS runnable_B,
  (b.runnable_tasks_count - a.runnable_tasks_count) AS delta_runnable,
  a.work_queue_count AS workq_A,
  b.work_queue_count AS workq_B,
  (b.work_queue_count - a.work_queue_count) AS delta_workq,
  a.load_factor AS load_A,
  b.load_factor AS load_B,
  (b.load_factor - a.load_factor) AS delta_load,
  b.status, b.is_online
FROM DBA_tools.baseline.SchedulerHealth a
JOIN DBA_tools.baseline.SchedulerHealth b
  ON b.scheduler_id = a.scheduler_id
WHERE a.run_id = @runA AND b.run_id = @runB
ORDER BY (b.runnable_tasks_count - a.runnable_tasks_count) DESC;

------------------------------------------------------------
-- 9) XE SPIKES: summary + latest events (RunB)
------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM DBA_tools.baseline.XEDeadlocks      WHERE run_id=@runA) AS deadlocks_A,
  (SELECT COUNT(*) FROM DBA_tools.baseline.XEDeadlocks      WHERE run_id=@runB) AS deadlocks_B,
  (SELECT COUNT(*) FROM DBA_tools.baseline.XEBlockedProcess WHERE run_id=@runA) AS blocked_A,
  (SELECT COUNT(*) FROM DBA_tools.baseline.XEBlockedProcess WHERE run_id=@runB) AS blocked_B;

SELECT TOP (@TopN)
  event_utc, deadlock_xml
FROM DBA_tools.baseline.XEDeadlocks
WHERE run_id = @runB
ORDER BY event_utc DESC;

SELECT TOP (@TopN)
  event_utc, report_xml
FROM DBA_tools.baseline.XEBlockedProcess
WHERE run_id = @runB
ORDER BY event_utc DESC;

------------------------------------------------------------
-- 10) TOP QUERIES DELTA (dm_exec_query_stats snapshot)
------------------------------------------------------------
;WITH a AS
(
  SELECT
    query_hash,
    query_plan_hash,
    SUM(total_worker_time_ms) AS cpu_ms_A,
    SUM(total_elapsed_time_ms) AS elapsed_ms_A,
    SUM(total_logical_reads) AS reads_A,
    SUM(execution_count) AS exec_A,
    MAX(statement_text) AS sample_A
  FROM DBA_tools.baseline.TopExecQueryStats
  WHERE run_id = @runA
  GROUP BY query_hash, query_plan_hash
),
b AS
(
  SELECT
    query_hash,
    query_plan_hash,
    SUM(total_worker_time_ms) AS cpu_ms_B,
    SUM(total_elapsed_time_ms) AS elapsed_ms_B,
    SUM(total_logical_reads) AS reads_B,
    SUM(execution_count) AS exec_B,
    MAX(statement_text) AS sample_B
  FROM DBA_tools.baseline.TopExecQueryStats
  WHERE run_id = @runB
  GROUP BY query_hash, query_plan_hash
)
SELECT TOP (@TopN)
  COALESCE(b.query_hash, a.query_hash) AS query_hash,
  COALESCE(b.query_plan_hash, a.query_plan_hash) AS query_plan_hash,
  ISNULL(a.cpu_ms_A,0) AS cpu_ms_A,
  ISNULL(b.cpu_ms_B,0) AS cpu_ms_B,
  ISNULL(b.cpu_ms_B,0)-ISNULL(a.cpu_ms_A,0) AS delta_cpu_ms,
  ISNULL(a.reads_A,0) AS reads_A,
  ISNULL(b.reads_B,0) AS reads_B,
  ISNULL(b.reads_B,0)-ISNULL(a.reads_A,0) AS delta_reads,
  ISNULL(a.elapsed_ms_A,0) AS elapsed_ms_A,
  ISNULL(b.elapsed_ms_B,0) AS elapsed_ms_B,
  ISNULL(b.elapsed_ms_B,0)-ISNULL(a.elapsed_ms_A,0) AS delta_elapsed_ms,
  ISNULL(a.exec_A,0) AS exec_A,
  ISNULL(b.exec_B,0) AS exec_B,
  ISNULL(b.exec_B,0)-ISNULL(a.exec_A,0) AS delta_exec,
  COALESCE(b.sample_B, a.sample_A) AS statement_text
FROM a
FULL JOIN b
  ON b.query_hash = a.query_hash
 AND b.query_plan_hash = a.query_plan_hash
ORDER BY delta_cpu_ms DESC;

------------------------------------------------------------
-- 11) NEW TOP QUERIES in RunB (nie było w RunA)
------------------------------------------------------------
;WITH a AS
(
  SELECT DISTINCT query_hash, query_plan_hash
  FROM DBA_tools.baseline.TopExecQueryStats
  WHERE run_id = @runA
),
b AS
(
  SELECT
    query_hash, query_plan_hash,
    SUM(total_worker_time_ms) AS cpu_ms_B,
    MAX(statement_text) AS statement_text
  FROM DBA_tools.baseline.TopExecQueryStats
  WHERE run_id = @runB
  GROUP BY query_hash, query_plan_hash
)
SELECT TOP (@TopN)
  b.query_hash, b.query_plan_hash, b.cpu_ms_B, b.statement_text
FROM b
LEFT JOIN a
  ON a.query_hash = b.query_hash AND a.query_plan_hash = b.query_plan_hash
WHERE a.query_hash IS NULL
ORDER BY b.cpu_ms_B DESC;
