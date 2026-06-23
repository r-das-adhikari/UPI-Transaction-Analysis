


/* ============================================================
   UPI TRANSACTION ANALYSIS — COMPLETE SQL ANALYSIS SCRIPT
   Database : UPI_Transactions_Data_DB (SQL Server)
   Tables   : customer_details, customer_feedback, device_info,
              fraud_alert, merchant, account_details,
              transaction_history
   ============================================================ */

    CREATE DATABASE UPI_Transactions_Data_DB;
    GO
    USE UPI_Transactions_Data_DB;
    GO
    SELECT TABLE_NAME 
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_TYPE = 'BASE TABLE';
    GO

    SELECT TOP 10 * FROM dbo.customer_details;
    GO
    SELECT TOP 10 * FROM dbo.customer_feedback;
    GO
    SELECT TOP 10 * FROM dbo.device_info;
    GO
    SELECT TOP 10 * FROM dbo.fraud_alert;
    GO
    SELECT TOP 10 * FROM dbo.merchant;
    GO
    SELECT TOP 10 * FROM dbo.account_details;
    GO
    SELECT TOP 10 * FROM dbo.transaction_history;
    GO

    SELECT PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY amount) OVER() AS p90_amount
    FROM transaction_history
    GO
    SELECT TOP 10 merchant_id, COUNT(*) AS txn_count
FROM transaction_history
GROUP BY merchant_id
ORDER BY txn_count DESC
 /* ============================================================
   STEP 1 — DATA VALIDATION & INTEGRITY CHECKS
   ============================================================ */

-- 1.1 Row counts across all tables
SELECT 'customer_details'   AS table_name, COUNT(*) AS row_count FROM customer_details   UNION ALL
SELECT 'customer_feedback',                COUNT(*)              FROM customer_feedback   UNION ALL
SELECT 'device_info',                      COUNT(*)              FROM device_info         UNION ALL
SELECT 'fraud_alert',                      COUNT(*)              FROM fraud_alert         UNION ALL
SELECT 'merchant',                         COUNT(*)              FROM merchant            UNION ALL
SELECT 'account_details',                  COUNT(*)              FROM account_details     UNION ALL
SELECT 'transaction_history',              COUNT(*)              FROM transaction_history;
 
 
-- 1.2 Foreign key check : customer_id in account_details must exist in customer_details
SELECT COUNT(*) AS orphan_account_details
FROM account_details a
WHERE NOT EXISTS (
    SELECT 1 FROM customer_details c WHERE c.customer_id = a.customer_id
);
 
-- 1.3 Foreign key check : customer_id in device_info must exist in customer_details
SELECT COUNT(*) AS orphan_device_info
FROM device_info d
WHERE NOT EXISTS (
    SELECT 1 FROM customer_details c WHERE c.customer_id = d.customer_id
);
 
-- 1.4 Foreign key check : customer_id in transaction_history must exist in customer_details
SELECT COUNT(*) AS orphan_txn_customer
FROM transaction_history t
WHERE NOT EXISTS (
    SELECT 1 FROM customer_details c WHERE c.customer_id = t.customer_id
);
 
-- 1.5 Foreign key check : customer_id in customer_feedback must exist in customer_details
SELECT COUNT(*) AS orphan_feedback_customer
FROM customer_feedback f
WHERE NOT EXISTS (
    SELECT 1 FROM customer_details c WHERE c.customer_id = f.customer_id
);
 
-- 1.6 Foreign key check : merchant_id in transaction_history must exist in merchant
--     (only for merchant_payment and bill_pay where merchant_id is not null)

SELECT COUNT(*) AS orphan_txn_merchant
FROM transaction_history t
WHERE t.merchant_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM merchant m WHERE m.merchant_id = t.merchant_id
);
 
-- 1.7 Foreign key check : upi_id in transaction_history must exist in account_details
SELECT COUNT(*) AS orphan_txn_upi
FROM transaction_history t
WHERE NOT EXISTS (
    SELECT 1 FROM account_details a WHERE a.upi_id = t.upi_id
);
 
-- 1.8 Foreign key check : device_id in transaction_history must exist in device_info
SELECT COUNT(*) AS orphan_txn_device
FROM transaction_history t
WHERE NOT EXISTS (
    SELECT 1 FROM device_info d WHERE d.device_id = t.device_id
);
 
-- 1.9 Foreign key check : transaction_id in fraud_alert must exist in transaction_history
SELECT COUNT(*) AS orphan_fraud_alert_txn
FROM fraud_alert fa
WHERE NOT EXISTS (
    SELECT 1 FROM transaction_history t WHERE t.transaction_id = fa.transaction_id
);
 
-- 1.10 Null check on critical columns in transaction_history
SELECT
    SUM(CASE WHEN transaction_id  IS NULL THEN 1 ELSE 0 END) AS null_transaction_id,
    SUM(CASE WHEN upi_id          IS NULL THEN 1 ELSE 0 END) AS null_upi_id,
    SUM(CASE WHEN customer_id     IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN amount          IS NULL THEN 1 ELSE 0 END) AS null_amount,
    SUM(CASE WHEN status          IS NULL THEN 1 ELSE 0 END) AS null_status,
    SUM(CASE WHEN fraud_flag      IS NULL THEN 1 ELSE 0 END) AS null_fraud_flag,
    SUM(CASE WHEN device_type     IS NULL THEN 1 ELSE 0 END) AS null_device_type,
    SUM(CASE WHEN merchant_id     IS NULL THEN 1 ELSE 0 END) AS null_merchant_id_expected,
    SUM(CASE WHEN failure_reason  IS NULL THEN 1 ELSE 0 END) AS null_failure_reason_expected
FROM transaction_history;
 
-- 1.11 Verify intentional nulls : merchant_id should only be null for send/receive
SELECT transaction_type, COUNT(*) AS null_merchant_count
FROM transaction_history
WHERE merchant_id IS NULL
GROUP BY transaction_type;
 
-- 1.12 Verify intentional nulls : failure_reason should only be null for non-failed txns
SELECT status, COUNT(*) AS null_failure_reason_count
FROM transaction_history
WHERE failure_reason IS NULL
GROUP BY status;
 
-- 1.13 Check for unexpected categorical values in transaction_history
SELECT DISTINCT status          FROM transaction_history;
SELECT DISTINCT transaction_type FROM transaction_history;
SELECT DISTINCT channel         FROM transaction_history;
SELECT DISTINCT device_type     FROM transaction_history;
 
-- 1.14 Check for unexpected categorical values in customer_details
SELECT DISTINCT gender FROM customer_details;
SELECT DISTINCT region FROM customer_details;
 
-- 1.15 Check risk_score range (should be 0 to 1)
SELECT
    MIN(risk_score) AS min_risk, MAX(risk_score) AS max_risk,
    SUM(CASE WHEN risk_score < 0 OR risk_score > 1 THEN 1 ELSE 0 END) AS out_of_range
FROM customer_details;
 
SELECT
    MIN(risk_score) AS min_risk, MAX(risk_score) AS max_risk,
    SUM(CASE WHEN risk_score < 0 OR risk_score > 1 THEN 1 ELSE 0 END) AS out_of_range
FROM merchant;
 
-- 1.16 Check for negative amounts
SELECT COUNT(*) AS negative_amount_count
FROM transaction_history
WHERE amount < 0;
 
-- 1.17 Check for duplicate primary keys
SELECT customer_id,   COUNT(*) FROM customer_details   GROUP BY customer_id   HAVING COUNT(*) > 1;
SELECT feedback_id,   COUNT(*) FROM customer_feedback  GROUP BY feedback_id   HAVING COUNT(*) > 1;
SELECT device_id,     COUNT(*) FROM device_info        GROUP BY device_id     HAVING COUNT(*) > 1;
SELECT alert_id,      COUNT(*) FROM fraud_alert        GROUP BY alert_id      HAVING COUNT(*) > 1;
SELECT merchant_id,   COUNT(*) FROM merchant           GROUP BY merchant_id   HAVING COUNT(*) > 1;
SELECT upi_id,        COUNT(*) FROM account_details    GROUP BY upi_id        HAVING COUNT(*) > 1;
SELECT transaction_id,COUNT(*) FROM transaction_history GROUP BY transaction_id HAVING COUNT(*) > 1;
 
 
/* ============================================================
   STEP 2 — KPI FRAMEWORK
   (Covers PDF Step 1 : Business Understanding & KPI Framework)
   ============================================================ */
 
-- 2.1 Total transaction volume and value
SELECT
    COUNT(*)                                          AS total_transactions,
    SUM(amount)                                       AS total_value_inr,
    AVG(amount)                                       AS avg_transaction_amount,
    MIN(amount)                                       AS min_amount,
    MAX(amount)                                       AS max_amount
FROM transaction_history;
 
-- 2.2 Transaction failure rate (overall)
SELECT
    COUNT(*)                                               AS total_transactions,
    SUM(CASE WHEN status = 'failed'  THEN 1 ELSE 0 END)   AS failed_count,
    SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END)   AS success_count,
    SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END)   AS pending_count,
    ROUND(100.0 * SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate_pct
FROM transaction_history;
 
-- 2.3 Fraud detection rate
SELECT
    COUNT(*)                                                          AS total_transactions,
    SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END)                  AS fraud_flagged_count,
    ROUND(100.0 * SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transaction_history;
 
-- 2.4 Reversal rate
SELECT
    SUM(CASE WHEN reversal_flag = 1 THEN 1 ELSE 0 END)               AS reversed_count,
    ROUND(100.0 * SUM(CASE WHEN reversal_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS reversal_rate_pct
FROM transaction_history;
 
-- 2.5 Fraud alert resolution rate
SELECT
    COUNT(*)                                                   AS total_alerts,
    SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END)             AS resolved_alerts,
    SUM(CASE WHEN resolved = 0 THEN 1 ELSE 0 END)             AS open_alerts,
    ROUND(100.0 * SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS resolution_rate_pct
FROM fraud_alert;
 
-- 2.6 Average fraud alert resolution time (in hours)
SELECT
    AVG(DATEDIFF(HOUR, alert_date, resolution_date)) AS avg_resolution_hours,
    MIN(DATEDIFF(HOUR, alert_date, resolution_date)) AS min_resolution_hours,
    MAX(DATEDIFF(HOUR, alert_date, resolution_date)) AS max_resolution_hours
FROM fraud_alert
WHERE resolved = 1 AND resolution_date IS NOT NULL;
 
-- 2.7 Customer retention (customers active in last 90 days)
SELECT
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT CASE WHEN timestamp >= DATEADD(DAY, -90, GETDATE()) THEN customer_id END) AS active_last_90_days,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN timestamp >= DATEADD(DAY, -90, GETDATE()) THEN customer_id END)
          / COUNT(DISTINCT customer_id), 2) AS retention_rate_pct
FROM transaction_history;
 
-- 2.8 Average customer satisfaction score
SELECT
    ROUND(AVG(CAST(satisfaction_score AS FLOAT)), 2)  AS avg_satisfaction_score,
    COUNT(*)                                           AS total_feedbacks,
    SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END)     AS resolved_feedbacks,
    ROUND(100.0 * SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS feedback_resolution_rate_pct
FROM customer_feedback;
 
 
/* ============================================================
   STEP 3 — EXPLORATORY DATA ANALYSIS & DESCRIPTIVE STATISTICS
   (Covers PDF Step 3 : EDA & Descriptive Statistics)
   ============================================================ */
 
-- 3.1 Transaction volume and value by transaction type
SELECT
    transaction_type,
    COUNT(*)        AS txn_count,
    SUM(amount)     AS total_amount,
    AVG(amount)     AS avg_amount,
    MIN(amount)     AS min_amount,
    MAX(amount)     AS max_amount
FROM transaction_history
GROUP BY transaction_type
ORDER BY txn_count DESC;
 
-- 3.2 Transaction volume by status per transaction type
SELECT
    transaction_type,
    status,
    COUNT(*)  AS txn_count,
    SUM(amount) AS total_amount
FROM transaction_history
GROUP BY transaction_type, status
ORDER BY transaction_type, status;
 
-- 3.3 Monthly transaction volume trend
SELECT
    FORMAT(timestamp, 'yyyy-MM')  AS year_month,
    COUNT(*)                       AS txn_count,
    SUM(amount)                    AS total_amount,
    SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END) AS fraud_count,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_count
FROM transaction_history
GROUP BY FORMAT(timestamp, 'yyyy-MM')
ORDER BY year_month;
 
-- 3.4 Daily transaction volume (last 30 days)
SELECT
    CAST(timestamp AS DATE)         AS txn_date,
    COUNT(*)                        AS txn_count,
    SUM(amount)                     AS total_amount
FROM transaction_history
WHERE timestamp >= DATEADD(DAY, -30, GETDATE())
GROUP BY CAST(timestamp AS DATE)
ORDER BY txn_date;
 
-- 3.5 Transaction volume by channel
SELECT
    channel,
    COUNT(*)                                               AS txn_count,
    SUM(amount)                                            AS total_amount,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2)     AS pct_share,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END)    AS failed_count,
    ROUND(100.0 * SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transaction_history
GROUP BY channel
ORDER BY txn_count DESC;
 
-- 3.6 Transaction volume by device type
SELECT
    device_type,
    COUNT(*)                                               AS txn_count,
    SUM(amount)                                            AS total_amount,
    SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END)       AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transaction_history
GROUP BY device_type
ORDER BY txn_count DESC;
 
-- 3.7 Transaction distribution by region (via customer)
SELECT
    c.region,
    COUNT(t.transaction_id)                               AS txn_count,
    SUM(t.amount)                                         AS total_amount,
    AVG(t.amount)                                         AS avg_amount,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)    AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transaction_history t
JOIN customer_details c ON t.customer_id = c.customer_id
GROUP BY c.region
ORDER BY txn_count DESC;
 
-- 3.8 Merchant activity summary
SELECT
    m.merchant_type,
    COUNT(DISTINCT t.merchant_id)                          AS active_merchants,
    COUNT(t.transaction_id)                                AS txn_count,
    SUM(t.amount)                                          AS total_amount,
    AVG(t.amount)                                          AS avg_amount,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)     AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transaction_history t
JOIN merchant m ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_type
ORDER BY txn_count DESC;
 
-- 3.9 Top 10 most active merchants
SELECT TOP 10
    m.merchant_id,
    m.merchant_name,
    m.merchant_type,
    m.region,
    COUNT(t.transaction_id) AS txn_count,
    SUM(t.amount)           AS total_amount
FROM transaction_history t
JOIN merchant m ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.merchant_type, m.region
ORDER BY txn_count DESC;
 
-- 3.10 Top 10 customers by transaction volume
SELECT TOP 10
    t.customer_id,
    c.full_name,
    c.region,
    COUNT(t.transaction_id) AS txn_count,
    SUM(t.amount)           AS total_amount,
    AVG(t.amount)           AS avg_amount
FROM transaction_history t
JOIN customer_details c ON t.customer_id = c.customer_id
GROUP BY t.customer_id, c.full_name, c.region
ORDER BY total_amount DESC;
 
-- 3.11 Customer demographics breakdown
SELECT
    gender,
    COUNT(*)          AS customer_count,
    AVG(age)          AS avg_age,
    AVG(risk_score)   AS avg_risk_score,
    SUM(CASE WHEN is_business_user = 1 THEN 1 ELSE 0 END) AS business_users
FROM customer_details
GROUP BY gender;
 
-- 3.12 Customer age group distribution
SELECT
    CASE
        WHEN age < 25          THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        ELSE '55+'
    END AS age_group,
    COUNT(*) AS customer_count,
    AVG(risk_score) AS avg_risk_score
FROM customer_details
GROUP BY
    CASE
        WHEN age < 25          THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        ELSE '55+'
    END
ORDER BY age_group;
 
-- 3.13 Account type distribution
SELECT
    account_type,
    COUNT(*)  AS account_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_share
FROM account_details
GROUP BY account_type
ORDER BY account_count DESC;
 
-- 3.14 Bank-wise account distribution
SELECT
    bank_name,
    COUNT(*)  AS account_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_share
FROM account_details
GROUP BY bank_name
ORDER BY account_count DESC;
 
-- 3.15 Transaction failure reason analysis
SELECT
    failure_reason,
    COUNT(*) AS failure_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_share
FROM transaction_history
WHERE status = 'failed' AND failure_reason IS NOT NULL
GROUP BY failure_reason
ORDER BY failure_count DESC;
 
-- 3.16 Hour-of-day transaction distribution (identify peak hours)
SELECT
    DATEPART(HOUR, timestamp) AS hour_of_day,
    COUNT(*)                  AS txn_count,
    SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END) AS fraud_count,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_count
FROM transaction_history
GROUP BY DATEPART(HOUR, timestamp)
ORDER BY hour_of_day;
 
-- 3.17 Day-of-week transaction distribution
SELECT
    DATENAME(WEEKDAY, timestamp) AS day_of_week,
    DATEPART(WEEKDAY, timestamp) AS day_num,
    COUNT(*)                     AS txn_count,
    SUM(amount)                  AS total_amount
FROM transaction_history
GROUP BY DATENAME(WEEKDAY, timestamp), DATEPART(WEEKDAY, timestamp)
ORDER BY day_num;
 
 
/* ============================================================
   STEP 4 — DERIVED KPI COLUMNS
   ============================================================ */
 
-- 4.1 Transaction Value per Customer
SELECT
    customer_id,
    COUNT(transaction_id)     AS total_transactions,
    SUM(amount)               AS total_amount,
    ROUND(SUM(amount) / COUNT(transaction_id), 2) AS txn_value_per_customer
FROM transaction_history
GROUP BY customer_id
ORDER BY txn_value_per_customer DESC;
 
-- 4.2 Merchant Fraud Ratio
SELECT
    t.merchant_id,
    m.merchant_name,
    m.merchant_type,
    m.region,
    m.risk_score                                                            AS merchant_risk_score,
    COUNT(t.transaction_id)                                                 AS total_txns,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                      AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS merchant_fraud_ratio_pct
FROM transaction_history t
JOIN merchant m ON t.merchant_id = m.merchant_id
GROUP BY t.merchant_id, m.merchant_name, m.merchant_type, m.region, m.risk_score
ORDER BY merchant_fraud_ratio_pct DESC;
 
-- 4.3 Device Fraud Ratio
SELECT
    t.device_type,
    COUNT(t.transaction_id)                                                 AS total_txns,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                      AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS device_fraud_ratio_pct
FROM transaction_history t
GROUP BY t.device_type
ORDER BY device_fraud_ratio_pct DESC;
 
-- 4.4 Transaction Failure Rate by channel
SELECT
    channel,
    COUNT(*)                                                                AS total_txns,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END)                     AS failed_txns,
    ROUND(100.0 * SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transaction_history
GROUP BY channel
ORDER BY failure_rate_pct DESC;
 
-- 4.5 Customer-level fraud and failure summary (high-risk customer identification)
SELECT
    t.customer_id,
    c.full_name,
    c.region,
    c.risk_score                                                             AS customer_risk_score,
    c.is_business_user,
    COUNT(t.transaction_id)                                                  AS total_txns,
    SUM(t.amount)                                                            AS total_amount,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                       AS fraud_txns,
    SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END)                    AS failed_txns,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2)  AS fraud_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transaction_history t
JOIN customer_details c ON t.customer_id = c.customer_id
GROUP BY t.customer_id, c.full_name, c.region, c.risk_score, c.is_business_user
ORDER BY fraud_rate_pct DESC;
 
 
/* ============================================================
   STEP 5 — FRAUD & ANOMALY DETECTION ANALYSIS
   ============================================================ */
 
-- 5.1 Fraud alert types and frequency
SELECT
    alert_type,
    COUNT(*)                                               AS alert_count,
    SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END)         AS resolved_count,
    SUM(CASE WHEN resolved = 0 THEN 1 ELSE 0 END)         AS open_count,
    ROUND(100.0 * SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS resolution_rate_pct,
    AVG(DATEDIFF(HOUR, alert_date, resolution_date))       AS avg_resolution_hours
FROM fraud_alert
GROUP BY alert_type
ORDER BY alert_count DESC;
 
-- 5.2 Fraud rate by region
SELECT
    c.region,
    COUNT(t.transaction_id)                                                  AS total_txns,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                       AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transaction_history t
JOIN customer_details c ON t.customer_id = c.customer_id
GROUP BY c.region
ORDER BY fraud_rate_pct DESC;
 
-- 5.3 Fraud rate by device type
SELECT
    device_type,
    COUNT(*)                                                                 AS total_txns,
    SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END)                         AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transaction_history
GROUP BY device_type
ORDER BY fraud_rate_pct DESC;
 
-- 5.4 Fraud rate by channel
SELECT
    channel,
    COUNT(*)                                                                 AS total_txns,
    SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END)                         AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transaction_history
GROUP BY channel
ORDER BY fraud_rate_pct DESC;
 
-- 5.5 Rooted device risk analysis (hypothesis: rooted devices have higher fraud rates)
SELECT
    d.is_rooted,
    COUNT(t.transaction_id)                                                  AS total_txns,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                       AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    AVG(t.amount)                                                            AS avg_txn_amount
FROM transaction_history t
JOIN device_info d ON t.device_id = d.device_id
GROUP BY d.is_rooted;
 
-- 5.6 High-value transaction fraud analysis (transactions above 90th percentile)
WITH percentile_calc AS (
    SELECT PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY amount) OVER() AS p90_amount
    FROM transaction_history
)
SELECT
    CASE WHEN t.amount >= p.p90_amount THEN 'High Value' ELSE 'Normal' END AS txn_segment,
    COUNT(*)                                                                 AS txn_count,
    SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END)                         AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transaction_history t
CROSS JOIN (SELECT DISTINCT PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY amount) OVER() AS p90_amount FROM transaction_history) p
GROUP BY CASE WHEN t.amount >= p.p90_amount THEN 'High Value' ELSE 'Normal' END;
 
-- 5.7 High merchant risk score vs fraud rate (hypothesis: high risk merchants have more fraud)
SELECT
    CASE
        WHEN m.risk_score >= 0.7 THEN 'High Risk (0.7-1.0)'
        WHEN m.risk_score >= 0.4 THEN 'Medium Risk (0.4-0.7)'
        ELSE 'Low Risk (0-0.4)'
    END AS merchant_risk_band,
    COUNT(t.transaction_id)                                                  AS total_txns,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                       AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transaction_history t
JOIN merchant m ON t.merchant_id = m.merchant_id
GROUP BY
    CASE
        WHEN m.risk_score >= 0.7 THEN 'High Risk (0.7-1.0)'
        WHEN m.risk_score >= 0.4 THEN 'Medium Risk (0.4-0.7)'
        ELSE 'Low Risk (0-0.4)'
    END
ORDER BY fraud_rate_pct DESC;
 
-- 5.8 Customer risk score vs fraud occurrence (correlation check)
SELECT
    CASE
        WHEN c.risk_score >= 0.7 THEN 'High Risk (0.7-1.0)'
        WHEN c.risk_score >= 0.4 THEN 'Medium Risk (0.4-0.7)'
        ELSE 'Low Risk (0-0.4)'
    END AS customer_risk_band,
    COUNT(t.transaction_id)                                                  AS total_txns,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                       AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    AVG(t.amount)                                                            AS avg_txn_amount
FROM transaction_history t
JOIN customer_details c ON t.customer_id = c.customer_id
GROUP BY
    CASE
        WHEN c.risk_score >= 0.7 THEN 'High Risk (0.7-1.0)'
        WHEN c.risk_score >= 0.4 THEN 'Medium Risk (0.4-0.7)'
        ELSE 'Low Risk (0-0.4)'
    END
ORDER BY fraud_rate_pct DESC;
 
-- 5.9 Unusual time (night transactions) fraud analysis
--     Hypothesis: transactions between midnight and 5am have higher fraud rates
SELECT
    CASE
        WHEN DATEPART(HOUR, timestamp) BETWEEN 0 AND 5   THEN 'Night (00-05)'
        WHEN DATEPART(HOUR, timestamp) BETWEEN 6 AND 11  THEN 'Morning (06-11)'
        WHEN DATEPART(HOUR, timestamp) BETWEEN 12 AND 17 THEN 'Afternoon (12-17)'
        ELSE 'Evening (18-23)'
    END AS time_band,
    COUNT(*)                                                                 AS total_txns,
    SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END)                         AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    COUNT(DISTINCT fa.alert_id)                                              AS fraud_alerts
FROM transaction_history t
LEFT JOIN fraud_alert fa ON t.transaction_id = fa.transaction_id
GROUP BY
    CASE
        WHEN DATEPART(HOUR, timestamp) BETWEEN 0 AND 5   THEN 'Night (00-05)'
        WHEN DATEPART(HOUR, timestamp) BETWEEN 6 AND 11  THEN 'Morning (06-11)'
        WHEN DATEPART(HOUR, timestamp) BETWEEN 12 AND 17 THEN 'Afternoon (12-17)'
        ELSE 'Evening (18-23)'
    END
ORDER BY fraud_rate_pct DESC;
 
-- 5.10 Top 10 high-risk merchants (by fraud ratio)
SELECT TOP 10
    m.merchant_id,
    m.merchant_name,
    m.merchant_type,
    m.region,
    m.risk_score,
    COUNT(t.transaction_id)                                                  AS total_txns,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                       AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transaction_history t
JOIN merchant m ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.merchant_type, m.region, m.risk_score
HAVING COUNT(t.transaction_id) >= 10   -- minimum 10 transactions for meaningful rate
ORDER BY fraud_rate_pct DESC;
 
-- 5.11 Transactions with both fraud_flag AND a fraud_alert (matched fraud)
SELECT
    COUNT(DISTINCT t.transaction_id)  AS flagged_in_both,
    COUNT(DISTINCT fa.alert_id)       AS total_alerts,
    COUNT(DISTINCT CASE WHEN t.fraud_flag = 1 THEN t.transaction_id END) AS flagged_transactions
FROM transaction_history t
LEFT JOIN fraud_alert fa ON t.transaction_id = fa.transaction_id;
 
-- 5.12 Fraud trend by month
SELECT
    FORMAT(timestamp, 'yyyy-MM')                                             AS year_month,
    COUNT(*)                                                                 AS total_txns,
    SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END)                         AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transaction_history
GROUP BY FORMAT(timestamp, 'yyyy-MM')
ORDER BY year_month;
 
 
/* ============================================================
   STEP 6 — CUSTOMER BEHAVIOR ANALYSIS
   ============================================================ */
 
-- 6.1 Business users vs regular users transaction comparison
SELECT
    c.is_business_user,
    COUNT(DISTINCT c.customer_id)                                            AS customer_count,
    COUNT(t.transaction_id)                                                  AS total_txns,
    SUM(t.amount)                                                            AS total_amount,
    AVG(t.amount)                                                            AS avg_txn_amount,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                       AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM customer_details c
LEFT JOIN transaction_history t ON c.customer_id = t.customer_id
GROUP BY c.is_business_user;
 
-- 6.2 Customer segmentation by transaction activity
WITH customer_txn AS (
    SELECT
        customer_id,
        COUNT(transaction_id) AS txn_count,
        SUM(amount)           AS total_amount
    FROM transaction_history
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN txn_count = 0          THEN 'Inactive'
        WHEN txn_count BETWEEN 1 AND 5  THEN 'Low Activity (1-5)'
        WHEN txn_count BETWEEN 6 AND 20 THEN 'Medium Activity (6-20)'
        ELSE 'High Activity (20+)'
    END AS activity_segment,
    COUNT(*)          AS customer_count,
    AVG(txn_count)    AS avg_txns,
    AVG(total_amount) AS avg_total_amount
FROM customer_txn
GROUP BY
    CASE
        WHEN txn_count = 0          THEN 'Inactive'
        WHEN txn_count BETWEEN 1 AND 5  THEN 'Low Activity (1-5)'
        WHEN txn_count BETWEEN 6 AND 20 THEN 'Medium Activity (6-20)'
        ELSE 'High Activity (20+)'
    END
ORDER BY avg_txns;
 
-- 6.3 Customers with no transactions (churned/inactive)
SELECT COUNT(*) AS customers_with_no_transactions
FROM customer_details c
WHERE NOT EXISTS (
    SELECT 1 FROM transaction_history t WHERE t.customer_id = c.customer_id
);
 
-- 6.4 New vs existing customer transaction behavior (joined in last 6 months)
SELECT
    CASE
        WHEN c.date_joined >= DATEADD(MONTH, -6, GETDATE()) THEN 'New Customer'
        ELSE 'Existing Customer'
    END AS customer_type,
    COUNT(DISTINCT c.customer_id)                                           AS customer_count,
    COUNT(t.transaction_id)                                                 AS total_txns,
    AVG(t.amount)                                                           AS avg_txn_amount,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS fraud_rate_pct
FROM customer_details c
LEFT JOIN transaction_history t ON c.customer_id = t.customer_id
GROUP BY
    CASE
        WHEN c.date_joined >= DATEADD(MONTH, -6, GETDATE()) THEN 'New Customer'
        ELSE 'Existing Customer'
    END;
 
-- 6.5 Customer feedback analysis by issue type
SELECT
    issue_type,
    COUNT(*)                                               AS feedback_count,
    AVG(CAST(satisfaction_score AS FLOAT))                 AS avg_satisfaction,
    SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END)         AS resolved_count,
    ROUND(100.0 * SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS resolution_rate_pct
FROM customer_feedback
GROUP BY issue_type
ORDER BY feedback_count DESC;
 
-- 6.6 Low satisfaction customers (score 1 or 2) with unresolved issues
SELECT
    cf.customer_id,
    c.full_name,
    c.region,
    cf.issue_type,
    cf.satisfaction_score,
    cf.resolved,
    cf.date_submitted
FROM customer_feedback cf
JOIN customer_details c ON cf.customer_id = c.customer_id
WHERE cf.satisfaction_score <= 2 AND cf.resolved = 0
ORDER BY cf.date_submitted DESC;
 
 
/* ============================================================
   STEP 7 — MERCHANT PERFORMANCE ANALYSIS
   ============================================================ */
 
-- 7.1 Merchant region vs failure rate (hypothesis: metro regions have lower failure)
SELECT
    m.region,
    COUNT(t.transaction_id)                                                  AS total_txns,
    SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END)                    AS failed_txns,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct,
    AVG(t.amount)                                                            AS avg_txn_amount
FROM transaction_history t
JOIN merchant m ON t.merchant_id = m.merchant_id
GROUP BY m.region
ORDER BY failure_rate_pct DESC;
 
-- 7.2 Merchant onboarding trend (new merchants per month)
SELECT
    FORMAT(onboard_date, 'yyyy-MM') AS onboard_month,
    COUNT(*)                         AS new_merchants
FROM merchant
GROUP BY FORMAT(onboard_date, 'yyyy-MM')
ORDER BY onboard_month;
 
-- 7.3 Merchants with zero transactions (inactive merchants)
SELECT COUNT(*) AS inactive_merchants
FROM merchant m
WHERE NOT EXISTS (
    SELECT 1 FROM transaction_history t WHERE t.merchant_id = m.merchant_id
);
 
-- 7.4 Top merchants by region
SELECT
    region,
    merchant_name,
    merchant_type,
    txn_count,
    total_amount
FROM (
    SELECT
        m.region,
        m.merchant_name,
        m.merchant_type,
        COUNT(t.transaction_id)  AS txn_count,
        SUM(t.amount)            AS total_amount,
        ROW_NUMBER() OVER (PARTITION BY m.region ORDER BY COUNT(t.transaction_id) DESC) AS rn
    FROM transaction_history t
    JOIN merchant m ON t.merchant_id = m.merchant_id
    GROUP BY m.region, m.merchant_name, m.merchant_type
) ranked
WHERE rn <= 3
ORDER BY region, txn_count DESC;
 
 
/* ============================================================
   STEP 8 — DEVICE & SECURITY ANALYSIS
   ============================================================ */
 
-- 8.1 Rooted device count and proportion
SELECT
    is_rooted,
    COUNT(*)  AS device_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_share
FROM device_info
GROUP BY is_rooted;
 
-- 8.2 Rooted devices by customer region
SELECT
    c.region,
    COUNT(d.device_id)                                                       AS total_devices,
    SUM(CASE WHEN d.is_rooted = 1 THEN 1 ELSE 0 END)                        AS rooted_devices,
    ROUND(100.0 * SUM(CASE WHEN d.is_rooted = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS rooted_pct
FROM device_info d
JOIN customer_details c ON d.customer_id = c.customer_id
GROUP BY c.region
ORDER BY rooted_pct DESC;
 
-- 8.3 App version distribution (identify outdated versions)
SELECT
    app_version,
    COUNT(*)   AS device_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_share
FROM device_info
GROUP BY app_version
ORDER BY device_count DESC;
 
-- 8.4 Devices inactive for more than 90 days (stale/abandoned)
SELECT
    COUNT(*) AS inactive_90_days_count
FROM device_info
WHERE last_active < DATEADD(DAY, -90, GETDATE());
 
-- 8.5 Device type breakdown with rooted proportion
SELECT
    device_type,
    COUNT(*)                                                                  AS total_devices,
    SUM(CASE WHEN is_rooted = 1 THEN 1 ELSE 0 END)                           AS rooted_count,
    ROUND(100.0 * SUM(CASE WHEN is_rooted = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS rooted_pct
FROM device_info
GROUP BY device_type
ORDER BY rooted_pct DESC;
 
 
/* ============================================================
   STEP 9 — STRATEGIC INSIGHTS & EXECUTIVE SUMMARY QUERIES
   ============================================================ */
 
-- 9.1 Full executive KPI summary (single result set for dashboard)
SELECT
    (SELECT COUNT(*) FROM transaction_history)                              AS total_transactions,
    (SELECT ROUND(SUM(amount), 2) FROM transaction_history)                 AS total_value_inr,
    (SELECT ROUND(AVG(amount), 2) FROM transaction_history)                 AS avg_txn_amount,
    (SELECT ROUND(100.0 * SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2)
     FROM transaction_history)                                               AS failure_rate_pct,
    (SELECT ROUND(100.0 * SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2)
     FROM transaction_history)                                               AS fraud_rate_pct,
    (SELECT ROUND(100.0 * SUM(CASE WHEN reversal_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2)
     FROM transaction_history)                                               AS reversal_rate_pct,
    (SELECT COUNT(*) FROM customer_details)                                 AS total_customers,
    (SELECT COUNT(*) FROM merchant)                                         AS total_merchants,
    (SELECT ROUND(AVG(CAST(satisfaction_score AS FLOAT)), 2)
     FROM customer_feedback)                                                 AS avg_satisfaction_score,
    (SELECT ROUND(100.0 * SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END) / COUNT(*), 2)
     FROM fraud_alert)                                                       AS fraud_alert_resolution_rate_pct;
 
-- 9.2 High-risk segment identification (customers needing intervention)
SELECT TOP 20
    c.customer_id,
    c.full_name,
    c.region,
    c.risk_score,
    c.is_business_user,
    COUNT(t.transaction_id)                                                   AS total_txns,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                        AS fraud_txns,
    SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END)                     AS failed_txns,
    COUNT(fa.alert_id)                                                        AS fraud_alerts,
    AVG(CAST(cf.satisfaction_score AS FLOAT))                                 AS avg_satisfaction
FROM customer_details c
LEFT JOIN transaction_history t   ON c.customer_id = t.customer_id
LEFT JOIN fraud_alert fa          ON t.transaction_id = fa.transaction_id
LEFT JOIN customer_feedback cf    ON c.customer_id = cf.customer_id
GROUP BY c.customer_id, c.full_name, c.region, c.risk_score, c.is_business_user
HAVING SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) > 0
ORDER BY fraud_alerts DESC, c.risk_score DESC;
 
-- 9.3 Region performance scorecard
SELECT
    c.region,
    COUNT(DISTINCT c.customer_id)                                            AS total_customers,
    COUNT(t.transaction_id)                                                  AS total_txns,
    ROUND(SUM(t.amount), 2)                                                  AS total_amount,
    ROUND(AVG(t.amount), 2)                                                  AS avg_txn_amount,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct,
    ROUND(AVG(c.risk_score), 4)                                              AS avg_customer_risk_score
FROM customer_details c
LEFT JOIN transaction_history t ON c.customer_id = t.customer_id
GROUP BY c.region
ORDER BY total_amount DESC;
 
-- 9.4 Merchant type performance scorecard
SELECT
    m.merchant_type,
    COUNT(DISTINCT m.merchant_id)                                            AS merchant_count,
    COUNT(t.transaction_id)                                                  AS total_txns,
    ROUND(SUM(t.amount), 2)                                                  AS total_amount,
    ROUND(AVG(t.amount), 2)                                                  AS avg_txn_amount,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct,
    ROUND(AVG(m.risk_score), 4)                                              AS avg_merchant_risk_score
FROM merchant m
LEFT JOIN transaction_history t ON m.merchant_id = t.merchant_id
GROUP BY m.merchant_type
ORDER BY total_amount DESC;
 
-- 9.5 Channel performance scorecard
SELECT
    t.channel,
    COUNT(*)                                                                  AS total_txns,
    ROUND(SUM(t.amount), 2)                                                   AS total_amount,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN t.reversal_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS reversal_rate_pct
FROM transaction_history t
GROUP BY t.channel
ORDER BY total_txns DESC;
 
-- 9.6 Monthly growth rate (month-over-month transaction volume change)
WITH monthly AS (
    SELECT
        FORMAT(timestamp, 'yyyy-MM') AS yr_month,
        COUNT(*)                      AS txn_count,
        SUM(amount)                   AS total_amount
    FROM transaction_history
    GROUP BY FORMAT(timestamp, 'yyyy-MM')
)
SELECT
    yr_month,
    txn_count,
    total_amount,
    LAG(txn_count)    OVER (ORDER BY yr_month) AS prev_month_txns,
    ROUND(100.0 * (txn_count - LAG(txn_count) OVER (ORDER BY yr_month))
          / NULLIF(LAG(txn_count) OVER (ORDER BY yr_month), 0), 2) AS mom_growth_pct
FROM monthly
ORDER BY yr_month;
 
-- 9.7 Overall data quality summary report
SELECT
    'customer_details'   AS table_name,
    (SELECT COUNT(*) FROM customer_details) AS total_rows,
    (SELECT COUNT(*) FROM customer_details WHERE risk_score IS NULL) AS null_risk_score,
    0 AS null_amount, 0 AS orphan_fk
UNION ALL
SELECT 'transaction_history',
    (SELECT COUNT(*) FROM transaction_history),
    0,
    (SELECT SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) FROM transaction_history),
    (SELECT COUNT(*) FROM transaction_history WHERE customer_id NOT IN (SELECT customer_id FROM customer_details))
UNION ALL
SELECT 'fraud_alert',
    (SELECT COUNT(*) FROM fraud_alert),
    0, 0,
    (SELECT COUNT(*) FROM fraud_alert WHERE transaction_id NOT IN (SELECT transaction_id FROM transaction_history));
 
/* ============================================================
   END OF ANALYSIS SCRIPT
   ============================================================ */
 
 
/* ============================================================
   STEP 10 — SQL DDL : DATABASE DESIGN & TABLE CREATION
   ============================================================ */
 
-- 10.1 DDL : customer_details
CREATE TABLE customer_details (
    customer_id       VARCHAR(50)     NOT NULL PRIMARY KEY,
    full_name         VARCHAR(200)    NOT NULL,
    mobile_number     VARCHAR(20)     NOT NULL,
    age               INT             NOT NULL CHECK (age > 0 AND age < 120),
    gender            VARCHAR(20)     NOT NULL,
    region            VARCHAR(50)     NOT NULL,
    date_joined       DATE            NOT NULL,
    is_business_user  BIT             NOT NULL DEFAULT 0,
    risk_score        FLOAT           NOT NULL CHECK (risk_score >= 0 AND risk_score <= 1)
);
 
-- 10.2 DDL : device_info
CREATE TABLE device_info (
    device_id     VARCHAR(50)   NOT NULL PRIMARY KEY,
    customer_id   VARCHAR(50)   NOT NULL,
    device_type   VARCHAR(50)   NOT NULL,
    app_version   VARCHAR(20)   NOT NULL,
    is_rooted     BIT           NOT NULL DEFAULT 0,
    last_active   DATETIME      NOT NULL,
    CONSTRAINT fk_device_customer FOREIGN KEY (customer_id)
        REFERENCES customer_details(customer_id)
);
 
-- 10.3 DDL : account_details
CREATE TABLE account_details (
    upi_id        VARCHAR(50)   NOT NULL PRIMARY KEY,
    customer_id   VARCHAR(50)   NOT NULL,
    bank_name     VARCHAR(50)   NOT NULL,
    account_type  VARCHAR(50)   NOT NULL,
    date_added    DATE          NOT NULL,
    status        VARCHAR(20)   NOT NULL CHECK (status IN ('active','blocked','suspended')),
    CONSTRAINT fk_account_customer FOREIGN KEY (customer_id)
        REFERENCES customer_details(customer_id)
);
 
-- 10.4 DDL : merchant
CREATE TABLE merchant (
    merchant_id    VARCHAR(50)   NOT NULL PRIMARY KEY,
    merchant_name  VARCHAR(200)  NOT NULL,
    merchant_type  VARCHAR(50)   NOT NULL,
    region         VARCHAR(50)   NOT NULL,
    onboard_date   DATE          NOT NULL,
    risk_score     FLOAT         NOT NULL CHECK (risk_score >= 0 AND risk_score <= 1)
);
 
-- 10.5 DDL : transaction_history
CREATE TABLE transaction_history (
    transaction_id    VARCHAR(50)   NOT NULL PRIMARY KEY,
    upi_id            VARCHAR(50)   NOT NULL,
    customer_id       VARCHAR(50)   NOT NULL,
    timestamp         DATETIME      NOT NULL,
    amount            FLOAT         NOT NULL CHECK (amount >= 0),
    transaction_type  VARCHAR(50)   NOT NULL,
    merchant_id       VARCHAR(50)   NULL,
    counterparty_upi  VARCHAR(50)   NOT NULL,
    status            VARCHAR(20)   NOT NULL CHECK (status IN ('success','failed','pending')),
    device_id         VARCHAR(50)   NOT NULL,
    device_type       VARCHAR(50)   NOT NULL,
    channel           VARCHAR(50)   NOT NULL,
    fraud_flag        BIT           NOT NULL DEFAULT 0,
    reversal_flag     BIT           NOT NULL DEFAULT 0,
    failure_reason    VARCHAR(100)  NULL,
    CONSTRAINT fk_txn_customer  FOREIGN KEY (customer_id)  REFERENCES customer_details(customer_id),
    CONSTRAINT fk_txn_upi       FOREIGN KEY (upi_id)       REFERENCES account_details(upi_id),
    CONSTRAINT fk_txn_device    FOREIGN KEY (device_id)    REFERENCES device_info(device_id),
    CONSTRAINT fk_txn_merchant  FOREIGN KEY (merchant_id)  REFERENCES merchant(merchant_id)
);
 
-- 10.6 DDL : customer_feedback
CREATE TABLE customer_feedback (
    feedback_id         VARCHAR(50)   NOT NULL PRIMARY KEY,
    customer_id         VARCHAR(50)   NOT NULL,
    date_submitted      DATE          NOT NULL,
    feedback_text       VARCHAR(500)  NULL,
    satisfaction_score  INT           NOT NULL CHECK (satisfaction_score BETWEEN 1 AND 5),
    issue_type          VARCHAR(50)   NOT NULL,
    resolved            BIT           NOT NULL DEFAULT 0,
    CONSTRAINT fk_feedback_customer FOREIGN KEY (customer_id)
        REFERENCES customer_details(customer_id)
);
 
-- 10.7 DDL : fraud_alert
CREATE TABLE fraud_alert (
    alert_id         VARCHAR(50)   NOT NULL PRIMARY KEY,
    transaction_id   VARCHAR(50)   NOT NULL,
    alert_type       VARCHAR(50)   NOT NULL,
    alert_date       DATETIME      NOT NULL,
    resolved         BIT           NOT NULL DEFAULT 0,
    resolution_date  DATETIME      NULL,
    remarks          VARCHAR(500)  NULL,
    CONSTRAINT fk_alert_txn FOREIGN KEY (transaction_id)
        REFERENCES transaction_history(transaction_id)
);
 
 
/* ============================================================
   STEP 11 — ACCOUNT & UPI ANALYSIS
   (Additional — Account Status, Multi-UPI, Bank Coverage)
   ============================================================ */
 
-- 11.1 Account status distribution
SELECT
    status,
    COUNT(*)  AS account_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_share
FROM account_details
GROUP BY status;
 
-- 11.2 Blocked or suspended accounts with recent transactions (security risk)
SELECT
    a.upi_id,
    a.customer_id,
    a.bank_name,
    a.account_type,
    a.status,
    COUNT(t.transaction_id)  AS txn_count_on_inactive_account,
    MAX(t.timestamp)         AS last_txn_date
FROM account_details a
JOIN transaction_history t ON a.upi_id = t.upi_id
WHERE a.status IN ('blocked', 'suspended')
GROUP BY a.upi_id, a.customer_id, a.bank_name, a.account_type, a.status
ORDER BY txn_count_on_inactive_account DESC;
 
-- 11.3 Customers with multiple UPI accounts (multi-mapping)
SELECT
    customer_id,
    COUNT(upi_id) AS upi_count,
    STRING_AGG(bank_name, ', ') AS banks
FROM account_details
GROUP BY customer_id
HAVING COUNT(upi_id) > 1
ORDER BY upi_count DESC;
 
-- 11.4 Bank-wise transaction volume and fraud
SELECT
    a.bank_name,
    COUNT(t.transaction_id)                                                   AS total_txns,
    ROUND(SUM(t.amount), 2)                                                   AS total_amount,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                        AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transaction_history t
JOIN account_details a ON t.upi_id = a.upi_id
GROUP BY a.bank_name
ORDER BY total_txns DESC;
 
-- 11.5 Account type vs transaction behavior
SELECT
    a.account_type,
    COUNT(t.transaction_id)                                                   AS total_txns,
    ROUND(AVG(t.amount), 2)                                                   AS avg_txn_amount,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                        AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transaction_history t
JOIN account_details a ON t.upi_id = a.upi_id
GROUP BY a.account_type
ORDER BY total_txns DESC;
 
 
/* ============================================================
   STEP 12 — REVERSAL ANALYSIS
   (Additional — Reversal patterns by channel, device, merchant)
   ============================================================ */
 
-- 12.1 Reversal rate by transaction type
SELECT
    transaction_type,
    COUNT(*)                                                                  AS total_txns,
    SUM(CASE WHEN reversal_flag = 1 THEN 1 ELSE 0 END)                       AS reversed_txns,
    ROUND(100.0 * SUM(CASE WHEN reversal_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS reversal_rate_pct
FROM transaction_history
GROUP BY transaction_type
ORDER BY reversal_rate_pct DESC;
 
-- 12.2 Reversal rate by channel
SELECT
    channel,
    COUNT(*)                                                                  AS total_txns,
    SUM(CASE WHEN reversal_flag = 1 THEN 1 ELSE 0 END)                       AS reversed_txns,
    ROUND(100.0 * SUM(CASE WHEN reversal_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS reversal_rate_pct
FROM transaction_history
GROUP BY channel
ORDER BY reversal_rate_pct DESC;
 
-- 12.3 Reversal rate by merchant type
SELECT
    m.merchant_type,
    COUNT(t.transaction_id)                                                   AS total_txns,
    SUM(CASE WHEN t.reversal_flag = 1 THEN 1 ELSE 0 END)                     AS reversed_txns,
    ROUND(100.0 * SUM(CASE WHEN t.reversal_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS reversal_rate_pct
FROM transaction_history t
JOIN merchant m ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_type
ORDER BY reversal_rate_pct DESC;
 
-- 12.4 Transactions that are both reversed AND fraud flagged
SELECT
    COUNT(*) AS reversed_and_fraud_count,
    ROUND(SUM(amount), 2) AS total_amount_at_risk
FROM transaction_history
WHERE reversal_flag = 1 AND fraud_flag = 1;
 
-- 12.5 Monthly reversal trend
SELECT
    FORMAT(timestamp, 'yyyy-MM')                                              AS year_month,
    COUNT(*)                                                                  AS total_txns,
    SUM(CASE WHEN reversal_flag = 1 THEN 1 ELSE 0 END)                       AS reversed_txns,
    ROUND(100.0 * SUM(CASE WHEN reversal_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS reversal_rate_pct
FROM transaction_history
GROUP BY FORMAT(timestamp, 'yyyy-MM')
ORDER BY year_month;
 
 
/* ============================================================
   STEP 13 — PENDING TRANSACTION AGING ANALYSIS
   (Additional — Identify stuck/stale pending transactions)
   ============================================================ */
 
-- 13.1 Pending transaction count and aging buckets
SELECT
    CASE
        WHEN DATEDIFF(DAY, timestamp, GETDATE()) <= 1    THEN '0-1 days'
        WHEN DATEDIFF(DAY, timestamp, GETDATE()) <= 7    THEN '2-7 days'
        WHEN DATEDIFF(DAY, timestamp, GETDATE()) <= 30   THEN '8-30 days'
        ELSE 'Over 30 days (stale)'
    END AS aging_bucket,
    COUNT(*)            AS pending_count,
    ROUND(SUM(amount), 2) AS total_amount_at_risk
FROM transaction_history
WHERE status = 'pending'
GROUP BY
    CASE
        WHEN DATEDIFF(DAY, timestamp, GETDATE()) <= 1    THEN '0-1 days'
        WHEN DATEDIFF(DAY, timestamp, GETDATE()) <= 7    THEN '2-7 days'
        WHEN DATEDIFF(DAY, timestamp, GETDATE()) <= 30   THEN '8-30 days'
        ELSE 'Over 30 days (stale)'
    END
ORDER BY pending_count DESC;
 
-- 13.2 Customers with highest pending amount at risk
SELECT TOP 10
    t.customer_id,
    c.full_name,
    c.region,
    COUNT(t.transaction_id)   AS pending_txns,
    ROUND(SUM(t.amount), 2)   AS total_pending_amount
FROM transaction_history t
JOIN customer_details c ON t.customer_id = c.customer_id
WHERE t.status = 'pending'
GROUP BY t.customer_id, c.full_name, c.region
ORDER BY total_pending_amount DESC;
 
 
/* ============================================================
   STEP 14 — STATISTICAL HYPOTHESIS QUERIES
   (Covers PDF Step 7 : Statistical Analysis)
   These serve as SQL-level proxies for the stats tests
   that would be run in Python (scipy/statsmodels).
   Run these first to understand group differences before
   applying t-test / ANOVA / chi-square in Python.
   ============================================================ */
 
-- 14.1 Average transaction amount by device type
--      (Input for T-test / ANOVA in Python)
SELECT
    device_type,
    COUNT(*)                  AS txn_count,
    ROUND(AVG(amount), 2)     AS mean_amount,
    ROUND(MIN(amount), 2)     AS min_amount,
    ROUND(MAX(amount), 2)     AS max_amount,
    ROUND(STDEV(amount), 2)   AS std_dev_amount
FROM transaction_history
GROUP BY device_type
ORDER BY mean_amount DESC;
 
-- 14.2 Average transaction amount by region
--      (Input for T-test / ANOVA in Python)
SELECT
    c.region,
    COUNT(t.transaction_id)   AS txn_count,
    ROUND(AVG(t.amount), 2)   AS mean_amount,
    ROUND(STDEV(t.amount), 2) AS std_dev_amount,
    ROUND(MIN(t.amount), 2)   AS min_amount,
    ROUND(MAX(t.amount), 2)   AS max_amount
FROM transaction_history t
JOIN customer_details c ON t.customer_id = c.customer_id
GROUP BY c.region
ORDER BY mean_amount DESC;
 
-- 14.3 Fraud rate variability by merchant type
--      (Input for ANOVA in Python)
SELECT
    m.merchant_type,
    COUNT(t.transaction_id)                                                   AS txn_count,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                        AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(AVG(CAST(t.fraud_flag AS FLOAT)), 4)                               AS fraud_mean,
    ROUND(STDEV(CAST(t.fraud_flag AS FLOAT)), 4)                             AS fraud_std_dev
FROM transaction_history t
JOIN merchant m ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_type
ORDER BY fraud_rate_pct DESC;
 
-- 14.4 Chi-square input : fraud flag vs channel (contingency table)
--      (Copy this output into Python for chi-square test)
SELECT
    channel,
    SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END) AS fraud_yes,
    SUM(CASE WHEN fraud_flag = 0 THEN 1 ELSE 0 END) AS fraud_no,
    COUNT(*) AS total
FROM transaction_history
GROUP BY channel
ORDER BY channel;
 
-- 14.5 Chi-square input : transaction status vs device type (contingency table)
SELECT
    device_type,
    SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) AS success_count,
    SUM(CASE WHEN status = 'failed'  THEN 1 ELSE 0 END) AS failed_count,
    SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS pending_count,
    COUNT(*) AS total
FROM transaction_history
GROUP BY device_type
ORDER BY device_type;
 
-- 14.6 Correlation proxy : customer risk_score bands vs fraud occurrence
--      (Input for Pearson correlation in Python)
SELECT
    c.customer_id,
    c.risk_score,
    COUNT(t.transaction_id)                                                   AS txn_count,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                        AS fraud_txns,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(t.transaction_id), 0), 2)                            AS individual_fraud_rate_pct
FROM customer_details c
LEFT JOIN transaction_history t ON c.customer_id = t.customer_id
GROUP BY c.customer_id, c.risk_score
ORDER BY c.risk_score DESC;
 
-- 14.7 Rooted device vs non-rooted fraud comparison
--      (Input for T-test / proportion test in Python)
SELECT
    d.is_rooted,
    COUNT(t.transaction_id)                                                   AS txn_count,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                        AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(AVG(t.amount), 2)                                                   AS avg_amount,
    ROUND(STDEV(t.amount), 2)                                                 AS std_dev_amount
FROM transaction_history t
JOIN device_info d ON t.device_id = d.device_id
GROUP BY d.is_rooted;
 
-- 14.8 Amount distribution percentiles (for outlier and anomaly detection)
SELECT
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY amount) OVER(), 2) AS p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY amount) OVER(), 2) AS p50_median,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY amount) OVER(), 2) AS p75,
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY amount) OVER(), 2) AS p90,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY amount) OVER(), 2) AS p95,
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY amount) OVER(), 2) AS p99
FROM transaction_history;
 
 
/* ============================================================
   STEP 15 — CUSTOMER SATISFACTION & FEEDBACK DEEP DIVE
   (Additional — Satisfaction trends, worst-rated segments)
   ============================================================ */
 
-- 15.1 Monthly satisfaction score trend
SELECT
    FORMAT(date_submitted, 'yyyy-MM')              AS year_month,
    COUNT(*)                                        AS feedback_count,
    ROUND(AVG(CAST(satisfaction_score AS FLOAT)), 2) AS avg_satisfaction,
    SUM(CASE WHEN satisfaction_score <= 2 THEN 1 ELSE 0 END) AS low_score_count,
    SUM(CASE WHEN satisfaction_score >= 4 THEN 1 ELSE 0 END) AS high_score_count
FROM customer_feedback
GROUP BY FORMAT(date_submitted, 'yyyy-MM')
ORDER BY year_month;
 
-- 15.2 Satisfaction score by region
SELECT
    c.region,
    COUNT(cf.feedback_id)                                    AS feedback_count,
    ROUND(AVG(CAST(cf.satisfaction_score AS FLOAT)), 2)      AS avg_satisfaction,
    SUM(CASE WHEN cf.resolved = 0 THEN 1 ELSE 0 END)         AS unresolved_issues
FROM customer_feedback cf
JOIN customer_details c ON cf.customer_id = c.customer_id
GROUP BY c.region
ORDER BY avg_satisfaction ASC;
 
-- 15.3 Unresolved issues older than 30 days (SLA breach)
SELECT
    cf.feedback_id,
    cf.customer_id,
    c.full_name,
    cf.issue_type,
    cf.satisfaction_score,
    cf.date_submitted,
    DATEDIFF(DAY, cf.date_submitted, GETDATE()) AS days_open
FROM customer_feedback cf
JOIN customer_details c ON cf.customer_id = c.customer_id
WHERE cf.resolved = 0
  AND cf.date_submitted < DATEADD(DAY, -30, GETDATE())
ORDER BY days_open DESC;
 
-- 15.4 Issue type resolution rate comparison
SELECT
    issue_type,
    COUNT(*)                                                  AS total_issues,
    SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END)            AS resolved_count,
    ROUND(100.0 * SUM(CASE WHEN resolved = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS resolution_rate_pct,
    ROUND(AVG(CAST(satisfaction_score AS FLOAT)), 2)          AS avg_satisfaction
FROM customer_feedback
GROUP BY issue_type
ORDER BY resolution_rate_pct ASC;
 
 
/* ============================================================
   STEP 16 — POWER BI READY VIEWS
   (Covers PDF Step 8 : Dashboard Development)
   These views can be directly imported into Power BI
   ============================================================ */
 
-- 16.1 Create view : Executive Dashboard KPIs
CREATE OR ALTER VIEW vw_executive_kpis AS
SELECT
    FORMAT(t.timestamp, 'yyyy-MM')                                            AS year_month,
    c.region,
    t.channel,
    t.device_type,
    t.transaction_type,
    COUNT(t.transaction_id)                                                   AS total_txns,
    ROUND(SUM(t.amount), 2)                                                   AS total_amount,
    ROUND(AVG(t.amount), 2)                                                   AS avg_amount,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                        AS fraud_count,
    SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END)                     AS failed_count,
    SUM(CASE WHEN t.reversal_flag = 1 THEN 1 ELSE 0 END)                     AS reversal_count,
    ROUND(100.0 * SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2)  AS fraud_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM transaction_history t
JOIN customer_details c ON t.customer_id = c.customer_id
GROUP BY FORMAT(t.timestamp, 'yyyy-MM'), c.region, t.channel, t.device_type, t.transaction_type;
 
-- 16.2 Create view : Fraud Analyst Dashboard
CREATE OR ALTER VIEW vw_fraud_analyst AS
SELECT
    t.transaction_id,
    t.customer_id,
    c.full_name,
    c.region,
    c.risk_score                                                               AS customer_risk_score,
    t.amount,
    t.transaction_type,
    t.channel,
    t.device_type,
    d.is_rooted,
    t.status,
    t.fraud_flag,
    t.reversal_flag,
    t.timestamp,
    fa.alert_id,
    fa.alert_type,
    fa.resolved                                                                AS alert_resolved,
    fa.alert_date,
    m.merchant_name,
    m.merchant_type,
    m.risk_score                                                               AS merchant_risk_score
FROM transaction_history t
JOIN customer_details c    ON t.customer_id   = c.customer_id
JOIN device_info d         ON t.device_id     = d.device_id
LEFT JOIN fraud_alert fa   ON t.transaction_id = fa.transaction_id
LEFT JOIN merchant m       ON t.merchant_id   = m.merchant_id;
 
-- 16.3 Create view : Customer 360 (full customer profile for Power BI)
CREATE OR ALTER VIEW vw_customer_360 AS
SELECT
    c.customer_id,
    c.full_name,
    c.age,
    c.gender,
    c.region,
    c.date_joined,
    c.is_business_user,
    c.risk_score,
    COUNT(DISTINCT a.upi_id)                                                   AS upi_account_count,
    COUNT(DISTINCT d.device_id)                                                AS device_count,
    COUNT(t.transaction_id)                                                    AS total_txns,
    ROUND(SUM(t.amount), 2)                                                    AS total_txn_amount,
    ROUND(AVG(t.amount), 2)                                                    AS avg_txn_amount,
    SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END)                         AS fraud_txns,
    SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END)                      AS failed_txns,
    ROUND(AVG(CAST(cf.satisfaction_score AS FLOAT)), 2)                        AS avg_satisfaction_score,
    MAX(t.timestamp)                                                           AS last_transaction_date
FROM customer_details c
LEFT JOIN account_details a      ON c.customer_id = a.customer_id
LEFT JOIN device_info d          ON c.customer_id = d.customer_id
LEFT JOIN transaction_history t  ON c.customer_id = t.customer_id
LEFT JOIN customer_feedback cf   ON c.customer_id = cf.customer_id
GROUP BY c.customer_id, c.full_name, c.age, c.gender, c.region,
         c.date_joined, c.is_business_user, c.risk_score;
 
/* ============================================================
   END OF COMPLETE SQL ANALYSIS SCRIPT
   Total sections : 16
   ============================================================ */