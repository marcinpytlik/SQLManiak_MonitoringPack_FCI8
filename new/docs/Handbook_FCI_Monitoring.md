# Handbook – FCI Monitoring
- Cel: szybka diagnoza awarii i trendów w FCI.
- Źródła: DMVs, XE, Errorlog, Query Store, PBM, Windows Failover Clustering.

## Procedury
1. Baseline po instalacji i większych zmianach.
2. XE user_activity – włącz tymczasowo podczas incydentów.
3. Health – codzienny raport CSV w `outputs/`.