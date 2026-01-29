EXEC DBA_tools.baseline.usp_CaptureBaseline
  @CaptureTopQueryStore = 1,
  @CapturePerDb = 1,
  @CaptureInstanceConfig = 1,
  @CaptureTraceFlags = 1,
  @CaptureTempdbLayout = 1,
  @CaptureRingBuffer = 1,
  @CaptureSchedulerHealth = 1,
  @CaptureXESpikes = 1,
  @CaptureTopExecQueryStats = 1,
  @TopN = 25,
  @Notes = N'auto short 5min';
