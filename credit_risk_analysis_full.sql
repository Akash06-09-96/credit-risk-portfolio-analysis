-- Credit Risk & Customer Analytics
-- Reproducible MySQL workflow
-- Dataset: UCI Default of Credit Card Clients
-- 30,000 customers; payment/default history across Apr-Sep 2005.

/* ============================================================
   1. RAW DATA PROFILING
   ============================================================ */

-- Basic row count.
SELECT COUNT(*) AS total_rows
FROM credit_card_clients_raw;

-- Duplicate customer ID check (should return 0 rows if IDs are unique).
SELECT Id, COUNT(*) AS duplicate_count
FROM credit_card_clients_raw
GROUP BY Id
HAVING COUNT(*) > 1;

-- Missing-value check across all 25 columns.
SELECT
    SUM(Id IS NULL) AS id_nulls,
    SUM(LIMIT_BAL IS NULL) AS limit_bal_nulls,
    SUM(SEX IS NULL) AS sex_nulls,
    SUM(EDUCATION IS NULL) AS education_nulls,
    SUM(MARRIAGE IS NULL) AS marriage_nulls,
    SUM(AGE IS NULL) AS age_nulls,
    SUM(PAY_0 IS NULL) AS pay_0_nulls,
    SUM(PAY_2 IS NULL) AS pay_2_nulls,
    SUM(PAY_3 IS NULL) AS pay_3_nulls,
    SUM(PAY_4 IS NULL) AS pay_4_nulls,
    SUM(PAY_5 IS NULL) AS pay_5_nulls,
    SUM(PAY_6 IS NULL) AS pay_6_nulls,
    SUM(BILL_AMT1 IS NULL) AS bill_amt1_nulls,
    SUM(BILL_AMT2 IS NULL) AS bill_amt2_nulls,
    SUM(BILL_AMT3 IS NULL) AS bill_amt3_nulls,
    SUM(BILL_AMT4 IS NULL) AS bill_amt4_nulls,
    SUM(BILL_AMT5 IS NULL) AS bill_amt5_nulls,
    SUM(BILL_AMT6 IS NULL) AS bill_amt6_nulls,
    SUM(PAY_AMT1 IS NULL) AS pay_amt1_nulls,
    SUM(PAY_AMT2 IS NULL) AS pay_amt2_nulls,
    SUM(PAY_AMT3 IS NULL) AS pay_amt3_nulls,
    SUM(PAY_AMT4 IS NULL) AS pay_amt4_nulls,
    SUM(PAY_AMT5 IS NULL) AS pay_amt5_nulls,
    SUM(PAY_AMT6 IS NULL) AS pay_amt6_nulls,
    SUM(`default payment next month` IS NULL) AS default_nulls
FROM credit_card_clients_raw;

-- How many customers had a bill amount exceeding their credit limit
-- in at least one of the six observed months (distinct from the
-- six-month AVERAGE utilization bands calculated later in this file).
SELECT
    COUNT(*) AS customers_over_limit_any_month
FROM credit_card_clients_raw
WHERE BILL_AMT1 > LIMIT_BAL
   OR BILL_AMT2 > LIMIT_BAL
   OR BILL_AMT3 > LIMIT_BAL
   OR BILL_AMT4 > LIMIT_BAL
   OR BILL_AMT5 > LIMIT_BAL
   OR BILL_AMT6 > LIMIT_BAL;

-- Education code distribution.
SELECT EDUCATION, COUNT(*) AS customers
FROM credit_card_clients_raw
GROUP BY EDUCATION
ORDER BY EDUCATION;

-- Marriage code distribution.
SELECT MARRIAGE, COUNT(*) AS customers
FROM credit_card_clients_raw
GROUP BY MARRIAGE
ORDER BY MARRIAGE;

-- Gender distribution.
SELECT SEX, COUNT(*) AS customers
FROM credit_card_clients_raw
GROUP BY SEX
ORDER BY SEX;

-- Target distribution.
SELECT `default payment next month` AS default_next_month,
       COUNT(*) AS customers
FROM credit_card_clients_raw
GROUP BY `default payment next month`;

-- Range checks for key numeric columns.
SELECT
    MIN(LIMIT_BAL) AS min_credit_limit,
    MAX(LIMIT_BAL) AS max_credit_limit,
    MIN(AGE) AS min_age,
    MAX(AGE) AS max_age,
    MIN(BILL_AMT1) AS min_sep_bill,
    MAX(BILL_AMT1) AS max_sep_bill,
    MIN(PAY_AMT1) AS min_sep_payment,
    MAX(PAY_AMT1) AS max_sep_payment
FROM credit_card_clients_raw;

/* ============================================================
   2. CLEAN / TRANSFORMED CUSTOMER TABLE
   ============================================================ */

DROP TABLE IF EXISTS credit_card_clients_clean;

CREATE TABLE credit_card_clients_clean AS
SELECT
    CAST(ID AS UNSIGNED) AS customer_id,
    CAST(LIMIT_BAL AS DECIMAL(14,2)) AS credit_limit,

    CASE
        WHEN SEX = 1 THEN 'Male'
        WHEN SEX = 2 THEN 'Female'
        ELSE 'Unknown'
    END AS gender,

    CASE
        WHEN EDUCATION = 1 THEN 'Graduate School'
        WHEN EDUCATION = 2 THEN 'University'
        WHEN EDUCATION = 3 THEN 'High School'
        ELSE 'Other/Unknown'
    END AS education_level,

    CASE
        WHEN MARRIAGE = 1 THEN 'Married'
        WHEN MARRIAGE = 2 THEN 'Single'
        ELSE 'Other/Unknown'
    END AS marital_status,

    CAST(AGE AS UNSIGNED) AS age,

    CAST(PAY_0 AS SIGNED) AS pay_status_sep,
    CAST(PAY_2 AS SIGNED) AS pay_status_aug,
    CAST(PAY_3 AS SIGNED) AS pay_status_jul,
    CAST(PAY_4 AS SIGNED) AS pay_status_jun,
    CAST(PAY_5 AS SIGNED) AS pay_status_may,
    CAST(PAY_6 AS SIGNED) AS pay_status_apr,

    CAST(BILL_AMT1 AS DECIMAL(14,2)) AS bill_amount_sep,
    CAST(BILL_AMT2 AS DECIMAL(14,2)) AS bill_amount_aug,
    CAST(BILL_AMT3 AS DECIMAL(14,2)) AS bill_amount_jul,
    CAST(BILL_AMT4 AS DECIMAL(14,2)) AS bill_amount_jun,
    CAST(BILL_AMT5 AS DECIMAL(14,2)) AS bill_amount_may,
    CAST(BILL_AMT6 AS DECIMAL(14,2)) AS bill_amount_apr,

    CAST(PAY_AMT1 AS DECIMAL(14,2)) AS payment_amount_sep,
    CAST(PAY_AMT2 AS DECIMAL(14,2)) AS payment_amount_aug,
    CAST(PAY_AMT3 AS DECIMAL(14,2)) AS payment_amount_jul,
    CAST(PAY_AMT4 AS DECIMAL(14,2)) AS payment_amount_jun,
    CAST(PAY_AMT5 AS DECIMAL(14,2)) AS payment_amount_may,
    CAST(PAY_AMT6 AS DECIMAL(14,2)) AS payment_amount_apr,

    CAST(`default payment next month` AS UNSIGNED) AS default_next_month
FROM credit_card_clients_raw;

-- Validation after transformation.
SELECT COUNT(*) AS clean_rows,
       COUNT(DISTINCT customer_id) AS distinct_customers
FROM credit_card_clients_clean;

/* ============================================================
   3. ANALYSIS 1 - SINGLE-MONTH REPAYMENT STATUS
   ============================================================ */

SELECT
    pay_status_sep,
    COUNT(*) AS total_customers,
    SUM(default_next_month) AS default_customers,
    ROUND(100.0 * SUM(default_next_month) / COUNT(*), 2) AS default_rate_pct
FROM credit_card_clients_clean
GROUP BY pay_status_sep
ORDER BY pay_status_sep;

/* ============================================================
   4. ANALYSIS 2 - MULTI-MONTH DELINQUENCY
   ============================================================ */

WITH customer_delinquency AS (
    SELECT
        customer_id,
        default_next_month,
        (pay_status_sep >= 1) +
        (pay_status_aug >= 1) +
        (pay_status_jul >= 1) +
        (pay_status_jun >= 1) +
        (pay_status_may >= 1) +
        (pay_status_apr >= 1) AS delinquent_months
    FROM credit_card_clients_clean
)
SELECT
    delinquent_months,
    COUNT(*) AS total_customers,
    SUM(default_next_month) AS default_customers,
    ROUND(100.0 * SUM(default_next_month) / COUNT(*), 2) AS default_rate_pct
FROM customer_delinquency
GROUP BY delinquent_months
ORDER BY delinquent_months;

/* ============================================================
   5. ANALYSIS 3 - CREDIT UTILIZATION
   ============================================================ */

WITH monthly_avg AS (
    SELECT
        customer_id,
        default_next_month,
        credit_limit,
        (bill_amount_sep + bill_amount_aug + bill_amount_jul +
         bill_amount_jun + bill_amount_may + bill_amount_apr) / 6.0 AS avg_bill_amount
    FROM credit_card_clients_clean
),
utilization AS (
    SELECT
        customer_id,
        default_next_month,
        ROUND(100.0 * avg_bill_amount / NULLIF(credit_limit, 0), 2) AS avg_utilization_pct
    FROM monthly_avg
),
banded AS (
    SELECT *,
        CASE
            WHEN avg_utilization_pct < 0 THEN '<0%'
            WHEN avg_utilization_pct < 25 THEN '0-24%'
            WHEN avg_utilization_pct < 50 THEN '25-49%'
            WHEN avg_utilization_pct < 75 THEN '50-74%'
            WHEN avg_utilization_pct < 100 THEN '75-99%'
            ELSE '100%+'
        END AS utilization_band
    FROM utilization
)
SELECT
    utilization_band,
    COUNT(*) AS total_customers,
    SUM(default_next_month) AS default_customers,
    ROUND(100.0 * SUM(default_next_month) / COUNT(*), 2) AS default_rate_pct
FROM banded
GROUP BY utilization_band
ORDER BY FIELD(utilization_band, '<0%', '0-24%', '25-49%', '50-74%', '75-99%', '100%+');

/* ============================================================
   6. ANALYSIS 4 - DELINQUENCY + UTILIZATION
   ============================================================ */

WITH metrics AS (
    SELECT
        customer_id,
        default_next_month,
        (pay_status_sep >= 1) + (pay_status_aug >= 1) +
        (pay_status_jul >= 1) + (pay_status_jun >= 1) +
        (pay_status_may >= 1) + (pay_status_apr >= 1) AS delinquent_months,
        100.0 * (
            (bill_amount_sep + bill_amount_aug + bill_amount_jul +
             bill_amount_jun + bill_amount_may + bill_amount_apr) / 6.0
        ) / NULLIF(credit_limit, 0) AS avg_utilization_pct
    FROM credit_card_clients_clean
),
segmented AS (
    SELECT *,
        CASE
            WHEN delinquent_months >= 3 THEN 'Persistent Delinquency'
            WHEN delinquent_months >= 1 THEN 'Occasional Delinquency'
            ELSE 'No Delinquency'
        END AS delinquency_group,
        CASE
            WHEN avg_utilization_pct >= 50 THEN 'High Utilization'
            ELSE 'Low Utilization'
        END AS utilization_group
    FROM metrics
)
SELECT
    utilization_group,
    delinquency_group,
    COUNT(*) AS total_customers,
    SUM(default_next_month) AS default_customers,
    ROUND(100.0 * SUM(default_next_month) / COUNT(*), 2) AS default_rate_pct
FROM segmented
GROUP BY utilization_group, delinquency_group
ORDER BY utilization_group, delinquency_group;

/* ============================================================
   7. ANALYSIS 5 - PAYMENT RATIO
   ============================================================ */

-- 7a. Percentile check (uses a window function) run BEFORE choosing the
-- payment bands below, to see the distribution's real shape rather than
-- assume it -- the mean (48.65%) was being pulled upward by a right-skewed
-- tail with a small number of very high ratios.
WITH payment_behavior AS (
    SELECT
        customer_id,
        (payment_amount_sep + payment_amount_aug + payment_amount_jul +
         payment_amount_jun + payment_amount_may + payment_amount_apr) AS total_payments,
        (bill_amount_sep + bill_amount_aug + bill_amount_jul +
         bill_amount_jun + bill_amount_may + bill_amount_apr) AS total_billed
    FROM credit_card_clients_clean
),
payment_ratio AS (
    SELECT
        customer_id,
        100.0 * total_payments / total_billed AS payment_ratio_pct
    FROM payment_behavior
    WHERE total_billed > 0
),
ranked AS (
    SELECT
        customer_id,
        payment_ratio_pct,
        PERCENT_RANK() OVER (ORDER BY payment_ratio_pct) AS percentile_rank
    FROM payment_ratio
)
SELECT
    ROUND(AVG(payment_ratio_pct), 2) AS mean_payment_ratio_pct,
    ROUND(MIN(CASE WHEN percentile_rank >= 0.25 THEN payment_ratio_pct END), 2) AS p25,
    ROUND(MIN(CASE WHEN percentile_rank >= 0.50 THEN payment_ratio_pct END), 2) AS median_p50,
    ROUND(MIN(CASE WHEN percentile_rank >= 0.75 THEN payment_ratio_pct END), 2) AS p75,
    ROUND(MIN(CASE WHEN percentile_rank >= 0.90 THEN payment_ratio_pct END), 2) AS p90,
    ROUND(MIN(CASE WHEN percentile_rank >= 0.95 THEN payment_ratio_pct END), 2) AS p95,
    ROUND(MIN(CASE WHEN percentile_rank >= 0.99 THEN payment_ratio_pct END), 2) AS p99
FROM ranked;
-- Result: Mean=48.65%, P25=4.25%, Median=9.45%, P75=62.29%, P90=100.14%, P95=118.69%, P99=282.05%
-- The output itself proves the mean was pulled upward by a right-skewed
-- tail (mean 48.65% vs. median 9.45%), which is why the bands below use
-- business-meaningful cutoffs rather than raw quartiles.
--
-- Note: this payment ratio (six-month payments / six-month statement
-- balances) is an analytical behavioural proxy, not a formal cash-flow
-- repayment rate -- monthly statement balances can carry forward from
-- prior months, so this should not be read as "percentage of original
-- debt repaid."

-- 7b. Banding customers into payment-behaviour groups and checking default rate.
WITH payment_metrics AS (
    SELECT
        customer_id,
        default_next_month,
        (bill_amount_sep + bill_amount_aug + bill_amount_jul +
         bill_amount_jun + bill_amount_may + bill_amount_apr) AS total_billed,
        (payment_amount_sep + payment_amount_aug + payment_amount_jul +
         payment_amount_jun + payment_amount_may + payment_amount_apr) AS total_payments
    FROM credit_card_clients_clean
),
ratios AS (
    SELECT
        customer_id,
        default_next_month,
        CASE
            WHEN total_billed > 0
            THEN 100.0 * total_payments / total_billed
            ELSE NULL
        END AS payment_ratio_pct
    FROM payment_metrics
),
banded AS (
    SELECT *,
        CASE
            WHEN payment_ratio_pct < 10 THEN 'Very Low Payment (<10%)'
            WHEN payment_ratio_pct < 25 THEN 'Low Payment (10-24%)'
            WHEN payment_ratio_pct < 50 THEN 'Moderate Payment (25-49%)'
            WHEN payment_ratio_pct < 100 THEN 'High Payment (50-99%)'
            ELSE 'Very High Payment (100%+)'
        END AS payment_band
    FROM ratios
    WHERE payment_ratio_pct IS NOT NULL
)
SELECT
    payment_band,
    COUNT(*) AS total_customers,
    SUM(default_next_month) AS default_customers,
    ROUND(100.0 * SUM(default_next_month) / COUNT(*), 2) AS default_rate_pct
FROM banded
GROUP BY payment_band
ORDER BY FIELD(
    payment_band,
    'Very Low Payment (<10%)',
    'Low Payment (10-24%)',
    'Moderate Payment (25-49%)',
    'High Payment (50-99%)',
    'Very High Payment (100%+)'
);

/* ============================================================
   8. HYPOTHESIS TEST - EQUAL-WEIGHT THREE-FLAG SCORE
   ============================================================ */

-- 8a. The initial equal-weight score, aggregated only by its 0-3 total.
-- This is the version that looked clean at first glance (14.11% -> 61.72%)
-- before the combination-level breakdown in 8b revealed it was hiding
-- very different risk levels within the same score.
WITH metrics AS (
    SELECT
        customer_id,
        default_next_month,
        (pay_status_sep >= 1) + (pay_status_aug >= 1) +
        (pay_status_jul >= 1) + (pay_status_jun >= 1) +
        (pay_status_may >= 1) + (pay_status_apr >= 1) AS delinquent_months,
        100.0 * ((bill_amount_sep + bill_amount_aug + bill_amount_jul +
                  bill_amount_jun + bill_amount_may + bill_amount_apr) / 6.0)
            / NULLIF(credit_limit, 0) AS avg_utilization_pct,
        CASE
            WHEN (bill_amount_sep + bill_amount_aug + bill_amount_jul +
                  bill_amount_jun + bill_amount_may + bill_amount_apr) > 0
            THEN 100.0 * (payment_amount_sep + payment_amount_aug + payment_amount_jul +
                          payment_amount_jun + payment_amount_may + payment_amount_apr)
                 / (bill_amount_sep + bill_amount_aug + bill_amount_jul +
                    bill_amount_jun + bill_amount_may + bill_amount_apr)
            ELSE NULL
        END AS payment_ratio_pct
    FROM credit_card_clients_clean
),
flags AS (
    SELECT *,
        (delinquent_months >= 3) AS persistent_delinquency_flag,
        (avg_utilization_pct >= 50) AS high_utilization_flag,
        (payment_ratio_pct < 10) AS very_low_payment_flag
    FROM metrics
)
SELECT
    persistent_delinquency_flag + high_utilization_flag + very_low_payment_flag AS risk_score,
    COUNT(*) AS total_customers,
    SUM(default_next_month) AS default_customers,
    ROUND(100.0 * SUM(default_next_month) / COUNT(*), 2) AS default_rate_pct
FROM flags
GROUP BY risk_score
ORDER BY risk_score;
-- Result: 0=14.11%, 1=17.38%, 2=25.49%, 3=61.72% -- looked like a clean,
-- usable score. The breakdown in 8b is what proved otherwise.

-- 8b. Same flags, broken down by the individual combination rather than
-- just the summed score -- this is what revealed the equal-weight score
-- was hiding very different risk levels underneath the same total.
WITH metrics AS (
    SELECT
        customer_id,
        default_next_month,
        (pay_status_sep >= 1) + (pay_status_aug >= 1) +
        (pay_status_jul >= 1) + (pay_status_jun >= 1) +
        (pay_status_may >= 1) + (pay_status_apr >= 1) AS delinquent_months,
        100.0 * ((bill_amount_sep + bill_amount_aug + bill_amount_jul +
                  bill_amount_jun + bill_amount_may + bill_amount_apr) / 6.0)
            / NULLIF(credit_limit, 0) AS avg_utilization_pct,
        CASE
            WHEN (bill_amount_sep + bill_amount_aug + bill_amount_jul +
                  bill_amount_jun + bill_amount_may + bill_amount_apr) > 0
            THEN 100.0 * (payment_amount_sep + payment_amount_aug + payment_amount_jul +
                          payment_amount_jun + payment_amount_may + payment_amount_apr)
                 / (bill_amount_sep + bill_amount_aug + bill_amount_jul +
                    bill_amount_jun + bill_amount_may + bill_amount_apr)
            ELSE NULL
        END AS payment_ratio_pct
    FROM credit_card_clients_clean
),
flags AS (
    SELECT *,
        (delinquent_months >= 3) AS persistent_delinquency_flag,
        (avg_utilization_pct >= 50) AS high_utilization_flag,
        (payment_ratio_pct < 10) AS very_low_payment_flag
    FROM metrics
)
SELECT
    persistent_delinquency_flag,
    high_utilization_flag,
    very_low_payment_flag,
    persistent_delinquency_flag + high_utilization_flag + very_low_payment_flag AS risk_score,
    COUNT(*) AS total_customers,
    SUM(default_next_month) AS default_customers,
    ROUND(100.0 * SUM(default_next_month) / COUNT(*), 2) AS default_rate_pct
FROM flags
GROUP BY persistent_delinquency_flag, high_utilization_flag, very_low_payment_flag
ORDER BY risk_score,
         persistent_delinquency_flag,
         high_utilization_flag,
         very_low_payment_flag;

/* ============================================================
   9. FINAL FROZEN RISK SEGMENTATION
   ============================================================ */

WITH metrics AS (
    SELECT
        customer_id,
        default_next_month,
        (pay_status_sep >= 1) + (pay_status_aug >= 1) +
        (pay_status_jul >= 1) + (pay_status_jun >= 1) +
        (pay_status_may >= 1) + (pay_status_apr >= 1) AS delinquent_months,
        100.0 * ((bill_amount_sep + bill_amount_aug + bill_amount_jul +
                  bill_amount_jun + bill_amount_may + bill_amount_apr) / 6.0)
            / NULLIF(credit_limit, 0) AS avg_utilization_pct,
        CASE
            WHEN (bill_amount_sep + bill_amount_aug + bill_amount_jul +
                  bill_amount_jun + bill_amount_may + bill_amount_apr) > 0
            THEN 100.0 * (payment_amount_sep + payment_amount_aug + payment_amount_jul +
                          payment_amount_jun + payment_amount_may + payment_amount_apr)
                 / (bill_amount_sep + bill_amount_aug + bill_amount_jul +
                    bill_amount_jun + bill_amount_may + bill_amount_apr)
            ELSE NULL
        END AS payment_ratio_pct
    FROM credit_card_clients_clean
),
segmented AS (
    SELECT *,
        CASE
            WHEN delinquent_months >= 3 AND payment_ratio_pct < 10
                THEN 'Critical Risk'
            WHEN delinquent_months >= 3
                THEN 'High Risk'
            WHEN delinquent_months < 3 AND avg_utilization_pct >= 50
                THEN 'Watchlist'
            ELSE 'Lower Risk'
        END AS risk_segment
    FROM metrics
)
SELECT
    risk_segment,
    COUNT(*) AS total_customers,
    SUM(default_next_month) AS default_customers,
    ROUND(100.0 * SUM(default_next_month) / COUNT(*), 2) AS default_rate_pct
FROM segmented
GROUP BY risk_segment
ORDER BY FIELD(risk_segment, 'Lower Risk', 'Watchlist', 'High Risk', 'Critical Risk');

/* ============================================================
   10. EXPOSURE ANALYSIS
   ============================================================ */

-- Positive September statement balance represents current outstanding exposure.
WITH exposure AS (
    SELECT
        *,
        CASE WHEN bill_amount_sep > 0 THEN bill_amount_sep ELSE 0 END AS outstanding_balance
    FROM credit_card_clients_clean
)
SELECT
    SUM(outstanding_balance) AS portfolio_outstanding_balance
FROM exposure;

/* ============================================================
   11. FINAL POWER BI REPORTING VIEW
   ============================================================ */

DROP VIEW IF EXISTS vw_credit_risk_analysis;

CREATE VIEW vw_credit_risk_analysis AS
WITH base_metrics AS (
    SELECT
        customer_id,
        gender,
        age,
        education_level,
        marital_status,
        credit_limit,
        default_next_month,

        (pay_status_sep >= 1) + (pay_status_aug >= 1) +
        (pay_status_jul >= 1) + (pay_status_jun >= 1) +
        (pay_status_may >= 1) + (pay_status_apr >= 1) AS delinquent_months,

        100.0 * ((bill_amount_sep + bill_amount_aug + bill_amount_jul +
                  bill_amount_jun + bill_amount_may + bill_amount_apr) / 6.0)
            / NULLIF(credit_limit, 0) AS avg_utilization_pct,

        CASE
            WHEN (bill_amount_sep + bill_amount_aug + bill_amount_jul +
                  bill_amount_jun + bill_amount_may + bill_amount_apr) > 0
            THEN 100.0 * (payment_amount_sep + payment_amount_aug + payment_amount_jul +
                          payment_amount_jun + payment_amount_may + payment_amount_apr)
                 / (bill_amount_sep + bill_amount_aug + bill_amount_jul +
                    bill_amount_jun + bill_amount_may + bill_amount_apr)
            ELSE NULL
        END AS payment_ratio_pct,

        CASE
            WHEN bill_amount_sep > 0 THEN bill_amount_sep
            ELSE 0
        END AS outstanding_balance
    FROM credit_card_clients_clean
),
segmented AS (
    SELECT
        *,
        CASE
            WHEN delinquent_months >= 3 AND payment_ratio_pct < 10
                THEN 'Critical Risk'
            WHEN delinquent_months >= 3
                THEN 'High Risk'
            WHEN delinquent_months < 3 AND avg_utilization_pct >= 50
                THEN 'Watchlist'
            ELSE 'Lower Risk'
        END AS risk_segment
    FROM base_metrics
)
SELECT
    customer_id,
    gender,
    age,
    education_level,
    marital_status,
    credit_limit,
    default_next_month,
    delinquent_months,
    ROUND(avg_utilization_pct, 2) AS avg_utilization_pct,
    ROUND(payment_ratio_pct, 2) AS payment_ratio_pct,
    outstanding_balance,
    risk_segment
FROM segmented;

/* ============================================================
   12. VALIDATION OF THE FINAL VIEW
   ============================================================ */

SELECT COUNT(*) AS total_customers
FROM vw_credit_risk_analysis;

SELECT
    risk_segment,
    COUNT(*) AS total_customers,
    SUM(default_next_month) AS default_customers,
    ROUND(100.0 * SUM(default_next_month) / COUNT(*), 2) AS default_rate_pct
FROM vw_credit_risk_analysis
GROUP BY risk_segment
ORDER BY FIELD(risk_segment, 'Lower Risk', 'Watchlist', 'High Risk', 'Critical Risk');

SELECT
    risk_segment,
    COUNT(*) AS total_customers,
    SUM(outstanding_balance) AS total_outstanding_balance,
    ROUND(AVG(outstanding_balance), 2) AS avg_outstanding_balance
FROM vw_credit_risk_analysis
GROUP BY risk_segment
ORDER BY FIELD(risk_segment, 'Lower Risk', 'Watchlist', 'High Risk', 'Critical Risk');

SELECT SUM(outstanding_balance) AS portfolio_outstanding_balance
FROM vw_credit_risk_analysis;
