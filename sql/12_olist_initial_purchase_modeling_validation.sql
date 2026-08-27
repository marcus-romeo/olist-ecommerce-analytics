-- VALIDATION 1: Confirm one row per customer
-- The total number of rows should equal the number of unique customers
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customer_initial_purchase_model;


-- VALIDATION 2: Confirm the target variable distribution
-- This verifies that the returning vs non-returning customers match the original modeling dataset
SELECT
    repeat_purchase_90d,
    COUNT(*) AS customers,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM customer_initial_purchase_model
GROUP BY repeat_purchase_90d
ORDER BY repeat_purchase_90d;


-- VALIDATION 3: Confirm the columns in the initial purchase modeling dataset
-- This verifies that the table contains the intended predictor variables and target
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'customer_initial_purchase_model'
ORDER BY ordinal_position;


-- VALIDATION 4: Confirm that post-purchase variables were excluded
-- This should return zero rows because these variables are not available at the time of purchase
SELECT
    column_name
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'customer_initial_purchase_model'
    AND column_name IN (
        'first_order_status',
        'review_score',
        'delivery_days',
        'delivery_variance_days',
        'delivery_status'
    );
