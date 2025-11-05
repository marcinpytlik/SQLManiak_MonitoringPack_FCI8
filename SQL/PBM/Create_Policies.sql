-- PBM: core policies (stubs + T-SQL installer). Adjust as needed.
USE msdb;
GO
-- Example: Backup Compression Default = ON (Server Configuration)
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syspolicy_conditions WHERE name = N'SRV_BackupCompressionDefault_ON')
BEGIN
  EXEC msdb.dbo.sp_syspolicy_add_condition
    @name = N'SRV_BackupCompressionDefault_ON',
    @facet = N'Server Configuration',
    @expression = N'<Operator><TypeClass>Bool</TypeClass><OpType>EQ</OpType><Count>2</Count><Attribute><TypeClass>Bool</TypeClass><Name>BackupCompressionDefault</Name></Attribute><Constant><TypeClass>Bool</TypeClass><ObjType>System.Boolean</ObjType><Bool>True</Bool></Constant></Operator>';
END
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syspolicy_policies WHERE name = N'PBM: Backup Compression Default = ON')
BEGIN
  EXEC msdb.dbo.sp_syspolicy_add_policy
    @name=N'PBM: Backup Compression Default = ON',
    @condition_name=N'SRV_BackupCompressionDefault_ON',
    @policy_category=N'DBA',
    @execution_mode=2;
END
GO
-- Example: Cost Threshold >= 30
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syspolicy_conditions WHERE name = N'SRV_CostThreshold_GE_30')
BEGIN
  EXEC msdb.dbo.sp_syspolicy_add_condition
    @name = N'SRV_CostThreshold_GE_30',
    @facet = N'Server Configuration',
    @expression = N'<Operator><TypeClass>Number</TypeClass><OpType>GE</OpType><Count>2</Count><Attribute><TypeClass>Number</TypeClass><Name>CostThresholdForParallelism</Name></Attribute><Constant><TypeClass>Number</TypeClass><ObjType>System.Int32</ObjType><Num>30</Num></Constant></Operator>';
END
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syspolicy_policies WHERE name = N'PBM: Cost Threshold >= 30')
BEGIN
  EXEC msdb.dbo.sp_syspolicy_add_policy
    @name=N'PBM: Cost Threshold >= 30',
    @condition_name=N'SRV_CostThreshold_GE_30',
    @policy_category=N'DBA',
    @execution_mode=2;
END
GO
-- Example: Database Auto Stats ON
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syspolicy_conditions WHERE name = N'DB_Stats_AutoOn')
BEGIN
  EXEC msdb.dbo.sp_syspolicy_add_condition
    @name = N'DB_Stats_AutoOn',
    @facet = N'Database',
    @expression = N'<Operator><TypeClass>Bool</TypeClass><OpType>AND</OpType><Count>2</Count><Operator><TypeClass>Bool</TypeClass><OpType>EQ</OpType><Count>2</Count><Attribute><TypeClass>Bool</TypeClass><Name>AutoCreateStatisticsEnabled</Name></Attribute><Constant><TypeClass>Bool</TypeClass><ObjType>System.Boolean</ObjType><Bool>True</Bool></Constant></Operator><Operator><TypeClass>Bool</TypeClass><OpType>EQ</OpType><Count>2</Count><Attribute><TypeClass>Bool</TypeClass><Name>AutoUpdateStatisticsEnabled</Name></Attribute><Constant><TypeClass>Bool</TypeClass><ObjType>System.Boolean</ObjType><Bool>True</Bool></Constant></Operator></Operator>';
END
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syspolicy_policies WHERE name = N'PBM: DB Stats Auto ON')
BEGIN
  EXEC msdb.dbo.sp_syspolicy_add_policy
    @name=N'PBM: DB Stats Auto ON',
    @condition_name=N'DB_Stats_AutoOn',
    @policy_category=N'DBA',
    @execution_mode=2,
    @target_set=N'<TargetSet><TargetTypeSet><TypeClass>Database</TypeClass><Name>DATABASE</Name><Enabled>True</Enabled></TargetTypeSet></TargetSet>';
END
GO
