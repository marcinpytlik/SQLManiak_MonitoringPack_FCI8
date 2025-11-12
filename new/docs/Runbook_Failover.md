# Runbook – Failover (FCI)
1. `Get-ClusterSummary.ps1` – stan klastra.
2. `Get-FCIHealth.ps1` – zasoby SQL.
3. Planowany failover: komunikacja, pauza zadań.
4. Po failoverze: `Health – FCI/Cluster` i `Baseline`.