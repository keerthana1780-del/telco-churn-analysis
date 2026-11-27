-- Telco Customer Churn: SQL analysis (SQLite)
-- Table "customers" was loaded from telco_cleaned.csv (7,043 rows).
-- Churn_flag: 1 = customer left, 0 = stayed.

-- Q1: Churn rate by contract type
SELECT Contract,
       COUNT(*) AS customers,
       SUM(Churn_flag) AS churned,
       ROUND(100.0 * SUM(Churn_flag) / COUNT(*), 1) AS churn_pct
FROM customers
GROUP BY Contract
ORDER BY churn_pct DESC;

-- Q2: Each contract's churn vs the overall rate (two CTEs)
WITH overall AS (
    SELECT 1.0 * SUM(Churn_flag) / COUNT(*) AS overall_rate
    FROM customers
),
by_contract AS (
    SELECT Contract,
           COUNT(*) AS customers,
           1.0 * SUM(Churn_flag) / COUNT(*) AS rate
    FROM customers
    GROUP BY Contract
)
SELECT b.Contract, b.customers,
       ROUND(100 * b.rate, 1) AS churn_pct,
       ROUND(100 * o.overall_rate, 1) AS overall_pct,
       ROUND(b.rate / o.overall_rate, 2) AS times_overall
FROM by_contract b
CROSS JOIN overall o
ORDER BY b.rate DESC;

-- Q3: Riskiest contract + internet segments (RANK window function)
WITH seg AS (
    SELECT Contract, InternetService,
           COUNT(*) AS customers,
           1.0 * SUM(Churn_flag) / COUNT(*) AS rate
    FROM customers
    GROUP BY Contract, InternetService
)
SELECT Contract, InternetService, customers,
       ROUND(100 * rate, 1) AS churn_pct,
       RANK() OVER (ORDER BY rate DESC) AS risk_rank
FROM seg
WHERE customers >= 100
ORDER BY risk_rank;

-- Q4: Running total of churn in the first 12 months of tenure
WITH m AS (
    SELECT tenure, SUM(Churn_flag) AS churned
    FROM customers
    GROUP BY tenure
)
SELECT tenure, churned,
       SUM(churned) OVER (ORDER BY tenure) AS running_churned,
       ROUND(100.0 * SUM(churned) OVER (ORDER BY tenure)
             / (SELECT SUM(Churn_flag) FROM customers), 1) AS cum_pct
FROM m
WHERE tenure <= 12
ORDER BY tenure;

-- Q5: Top 3 highest-paying churned customers per contract (ROW_NUMBER + PARTITION BY)
SELECT Contract, customerID, MonthlyCharges, tenure, rn
FROM (
    SELECT Contract, customerID, MonthlyCharges, tenure,
           ROW_NUMBER() OVER (PARTITION BY Contract
                              ORDER BY MonthlyCharges DESC) AS rn
    FROM customers
    WHERE Churn_flag = 1
)
WHERE rn <= 3
ORDER BY Contract, rn;

-- Q6: Payment methods ranked by churn inside each contract type
WITH pm AS (
    SELECT PaymentMethod, Contract,
           COUNT(*) AS customers,
           1.0 * SUM(Churn_flag) / COUNT(*) AS rate
    FROM customers
    GROUP BY PaymentMethod, Contract
)
SELECT PaymentMethod, Contract, customers,
       ROUND(100 * rate, 1) AS churn_pct,
       RANK() OVER (PARTITION BY Contract ORDER BY rate DESC) AS rank_in_contract
FROM pm
ORDER BY Contract, rank_in_contract;
