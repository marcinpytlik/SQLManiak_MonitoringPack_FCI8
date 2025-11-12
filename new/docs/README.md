# SQLManiak_MonitoringPack_FCI8 – FULL (2025-11-12)

Pełny pakiet monitoringu dla **SQL Server 2022 (Windows, FCI/standalone)** z naciskiem na: baseline, Extended Events, Query Store, PBM, health-check **FCI/cluster** oraz szybkie uruchomienie w **VS Code + PowerShell**.

## Zawartość (skrót)
- **dbadmin** – login/user/schemat + minimalne uprawnienia (VIEW SERVER STATE, VIEW DATABASE STATE).
- **Baseline** – skrypty inwentaryzacji instancji i baz (CSV + Markdown).
- **Extended Events** – sesje: `system_health_clone` (rozszerzona) i `user_activity` (z logowaniem statementów + błędów).
- **Query Store** – raporty regresji i konfiguracja QS (jeśli aktywny).
- **PBM (Policy-Based Management)** – import polityk + skrypt oceny zgodności.
- **Health (FCI/AG)** – zdrowie klastra, dysków, failoverów, stan FCI i HADR.
- **Jobs** – przykład joba do baseline dziennego.
- **Security/Audit** – szybki audyt konfiguracji serwera.
- **.vscode** – zadania do jednego kliknięcia.

## Szybki start
1. Zmień placeholdery haseł, ścieżek i nazw serwerów w `scripts/sql` oraz `scripts/powershell` (oznaczone komentarzami).
2. Uruchom VS Code → `Terminal > Run Task…`:
   - **Setup dbadmin (Windows/SQL Auth)**
   - **Baseline – Instance & Databases**
   - **Deploy XE (system_health_clone + user_activity)**
   - **PBM – Import & Evaluate**
   - **Health – FCI/Cluster quick check**
3. Wyniki lądują w folderze **outputs** (CSV/Markdown).

## Minimalne wymagania
- PowerShell 5.1+, moduł **SqlServer** (`Install-Module SqlServer -Scope CurrentUser`).
- Uprawnienia sysadmin lub równoważne (na czas wdrożenia – potem wystarczą uprawnienia jak w `dbadmin`).

---
Autor: SQLManiak • Licencja: CC BY 4.0