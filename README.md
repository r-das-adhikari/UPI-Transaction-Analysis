# UPI-Transaction-Analysis
End-to-end UPI transaction analytics project — Python ETL pipeline, SQL Server analysis (123 queries), and 3 Tableau dashboards covering fraud detection, customer behavior, and merchant performance.

## Project Overview
End-to-end data analytics project analyzing 140,500 UPI 
transactions across 7 relational tables, covering fraud 
detection, customer behavior, and merchant performance.

## Tools Used
- Python (pandas, SQLAlchemy) — ETL pipeline
- SQL Server — relational database & analysis
- Tableau — interactive dashboards

## Dataset
7 tables | 140,500 transaction records | 2024–2025

## Project Structure
/notebooks     → Python ETL pipeline (Jupyter)
/sql           → Complete SQL analysis (123 queries)
/screenshots   → Dashboard previews

## Key Findings
- Rooted devices show 20.69% fraud rate vs 1.39% for 
  non-rooted devices — 15x higher risk
- Electronics and apparel merchant types sit above average 
  fraud rate and transaction volume
- Feature phone transactions show the highest fraud rate 
  by device type at 2.15%
- 248 fraud alerts currently unresolved, avg resolution 
  time 35 hours

## Dashboards
1. Executive Overview — volume, value, and risk KPIs
2. Fraud & Operations Analyst — alert tracking and 
   device-level fraud patterns  
3. Customer & Merchant Insights — behavior, satisfaction, 
   and merchant performance

## Pipeline Features
- Automated ETL with logging (console + file handlers)
- Smart upsert logic (duplicate detection)
- Data validation (FK checks, null checks, range checks)
- Transaction rollback on upload failure
- Row count verification after each table upload
