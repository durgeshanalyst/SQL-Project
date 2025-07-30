/*
 Project Name: Financial Transactions – Spend & Fraud Analysis
Domain: Banking / FinTech
Author: LBA Analytics and AI (Durgesh)
Website: https://letsbeanalyst.com
Description: SQL project for identifying fraud, classifying spending,and monitoring financial transactions
Date Created: 2025-07-30
*/

/*******************************************************************************************
 Project: Financial Transactions – Spend & Fraud Analysis
 Domain: Banking / FinTech
 Author: LBA Analytics & AI | Durgesh
 Description: This SQL script analyzes synthetic banking transactions data to extract 
              insights on spending patterns, fraud detection, customer behavior, and more.
********************************************************************************************/

/* Sample Table Structure Assumed:
   transactions (txn_id, customer_id, txn_date, txn_amount, category, txn_type, region, is_fraud)
   customers (customer_id, name, gender, dob, location, join_date)
   accounts (account_id, customer_id, account_type, balance, open_date, status)
*/

------------------------------
-- 1. Monthly Spend Overview
------------------------------
WITH
    MonthlySpend
    AS
    (
        SELECT
            FORMAT(txn_date, 'yyyy-MM') AS month,
            SUM(txn_amount) AS total_spend
        FROM transactions
        WHERE txn_type = 'debit'
        GROUP BY FORMAT(txn_date, 'yyyy-MM')
    )
SELECT *
FROM MonthlySpend
ORDER BY month;

------------------------------
-- 2. Category-wise Spending Trend
------------------------------
SELECT
    category,
    FORMAT(txn_date, 'yyyy-MM') AS month,
    SUM(txn_amount) AS category_spend
FROM transactions
WHERE txn_type = 'debit'
GROUP BY category, FORMAT(txn_date, 'yyyy-MM')
ORDER BY category, month;

------------------------------
-- 3. Top 10 High-Value Customers
------------------------------
SELECT TOP 10
    c.customer_id,
    c.name,
    SUM(t.txn_amount) AS total_spent
FROM transactions t
    JOIN customers c ON c.customer_id = t.customer_id
WHERE t.txn_type = 'debit'
GROUP BY c.customer_id, c.name
ORDER BY total_spent DESC;

------------------------------
-- 4. Average Transaction Amount per Region
------------------------------
SELECT
    region,
    AVG(txn_amount) AS avg_txn_amt
FROM transactions
GROUP BY region;

------------------------------
-- 5. Suspicious Transaction Detection (Rule-based)
-- Rule: More than 3 transactions in <5 minutes with amount > ₹50,000
------------------------------
WITH
    TimeWindowed
    AS
    (
        SELECT *,
            LAG(txn_date, 1) OVER (PARTITION BY customer_id ORDER BY txn_date) AS prev_txn_time
        FROM transactions
    )
SELECT
    customer_id,
    txn_id,
    txn_date,
    txn_amount
FROM TimeWindowed
WHERE DATEDIFF(MINUTE, prev_txn_time, txn_date) < 5 AND txn_amount > 50000;

------------------------------
-- 6. Region-wise Fraud Rate
------------------------------
SELECT
    region,
    COUNT(CASE WHEN is_fraud = 1 THEN 1 END) * 100.0 / COUNT(*) AS fraud_rate_pct
FROM transactions
GROUP BY region
ORDER BY fraud_rate_pct DESC;

------------------------------
-- 7. Net Inflow vs Outflow per Customer
------------------------------
SELECT
    customer_id,
    SUM(CASE WHEN txn_type = 'credit' THEN txn_amount ELSE 0 END) AS total_inflow,
    SUM(CASE WHEN txn_type = 'debit' THEN txn_amount ELSE 0 END) AS total_outflow
FROM transactions
GROUP BY customer_id;

------------------------------
-- 8. Transaction Volume by Day of Week
------------------------------
SELECT
    DATENAME(WEEKDAY, txn_date) AS day_name,
    COUNT(*) AS txn_count
FROM transactions
GROUP BY DATENAME(WEEKDAY, txn_date)
ORDER BY txn_count DESC;

------------------------------
-- 9. Daily Transaction Rolling Average (7-day)
------------------------------
WITH
    DailyTxn
    AS
    (
        SELECT
            CAST(txn_date AS DATE) AS txn_day,
            SUM(txn_amount) AS total_spend
        FROM transactions
        WHERE txn_type = 'debit'
        GROUP BY CAST(txn_date AS DATE)
    )
SELECT
    txn_day,
    total_spend,
    AVG(total_spend) OVER (ORDER BY txn_day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7d_avg
FROM DailyTxn;

------------------------------
-- 10. Gender-wise Spending Distribution
------------------------------
SELECT
    c.gender,
    COUNT(t.txn_id) AS txn_count,
    SUM(t.txn_amount) AS total_spent
FROM transactions t
    JOIN customers c ON c.customer_id = t.customer_id
WHERE t.txn_type = 'debit'
GROUP BY c.gender;

------------------------------
-- 11. High Value Fraudulent Transactions
------------------------------
SELECT
    txn_id,
    customer_id,
    txn_date,
    txn_amount,
    region,
    category
FROM transactions
WHERE is_fraud = 1 AND txn_amount > 100000
ORDER BY txn_amount DESC;

------------------------------
-- 12. Inactive Customers (No Transactions in Last 6 Months)
------------------------------
SELECT
    c.customer_id,
    c.name,
    MAX(t.txn_date) AS last_txn_date
FROM customers c
    LEFT JOIN transactions t ON t.customer_id = c.customer_id
GROUP BY c.customer_id, c.name
HAVING MAX(t.txn_date) < DATEADD(MONTH, -6, GETDATE());

------------------------------
-- 13. Customer Retention Score using RFM Segmentation
------------------------------
WITH
    RFM
    AS
    (
        SELECT
            t.customer_id,
            DATEDIFF(DAY, MAX(t.txn_date), GETDATE()) AS recency,
            COUNT(t.txn_id) AS frequency,
            SUM(t.txn_amount) AS monetary
        FROM transactions t
        WHERE txn_type = 'debit'
        GROUP BY t.customer_id
    )
SELECT *,
    CASE 
    WHEN recency <= 30 AND frequency >= 10 AND monetary > 50000 THEN 'High Value'
    WHEN recency <= 60 THEN 'Medium Value'
    ELSE 'Low Value'
  END AS retention_segment
FROM RFM;

------------------------------
-- 14. 🔍 High-Level Analysis 1: Customer Transaction Behavior Deep-Dive
-- Includes: Monthly avg., spikes, standard deviation, txn type split, fraud %, and last txn time
------------------------------
WITH
    MonthlyStats
    AS
    (
        SELECT
            customer_id,
            FORMAT(txn_date, 'yyyy-MM') AS txn_month,
            COUNT(*) AS txn_count,
            SUM(txn_amount) AS total_amt,
            AVG(txn_amount) AS avg_amt,
            STDEV(txn_amount) AS std_dev
        FROM transactions
        GROUP BY customer_id, FORMAT(txn_date, 'yyyy-MM')
    ),
    TxnTypeSplit
    AS
    (
        SELECT
            customer_id,
            SUM(CASE WHEN txn_type = 'credit' THEN txn_amount ELSE 0 END) AS credit_total,
            SUM(CASE WHEN txn_type = 'debit' THEN txn_amount ELSE 0 END) AS debit_total
        FROM transactions
        GROUP BY customer_id
    ),
    FraudRate
    AS
    (
        SELECT
            customer_id,
            COUNT(CASE WHEN is_fraud = 1 THEN 1 END) * 1.0 / COUNT(*) AS fraud_pct
        FROM transactions
        GROUP BY customer_id
    ),
    LatestTxn
    AS
    (
        SELECT customer_id, MAX(txn_date) AS last_txn
        FROM transactions
        GROUP BY customer_id
    )
SELECT
    m.customer_id,
    AVG(m.avg_amt) AS avg_monthly_txn_amt,
    AVG(m.std_dev) AS avg_monthly_std_dev,
    t.credit_total,
    t.debit_total,
    f.fraud_pct,
    l.last_txn
FROM MonthlyStats m
    JOIN TxnTypeSplit t ON m.customer_id = t.customer_id
    JOIN FraudRate f ON m.customer_id = f.customer_id
    JOIN LatestTxn l ON m.customer_id = l.customer_id
GROUP BY m.customer_id, t.credit_total, t.debit_total, f.fraud_pct, l.last_txn;

------------------------------
-- 15. 🔍 High-Level Analysis 2: Fraud Trend Over Time by Region and Category
-- Includes: Monthly fraud %, cumulative cases, category severity
------------------------------
WITH
    FraudData
    AS
    (
        SELECT
            region,
            category,
            FORMAT(txn_date, 'yyyy-MM') AS txn_month,
            COUNT(*) AS total_txns,
            SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_txns
        FROM transactions
        GROUP BY region, category, FORMAT(txn_date, 'yyyy-MM')
    ),
    FraudRateCalc
    AS
    (
        SELECT *,
            fraud_txns * 100.0 / total_txns AS fraud_pct
        FROM FraudData
    ),
    CategorySeverity
    AS
    (
        SELECT
            category,
            SUM(fraud_txns) AS total_frauds,
            RANK() OVER (ORDER BY SUM(fraud_txns) DESC) AS severity_rank
        FROM FraudData
        GROUP BY category
    )
SELECT
    f.txn_month,
    f.region,
    f.category,
    f.fraud_txns,
    f.total_txns,
    f.fraud_pct,
    c.severity_rank
FROM FraudRateCalc f
    JOIN CategorySeverity c ON f.category = c.category
ORDER BY f.txn_month, f.fraud_pct DESC;
