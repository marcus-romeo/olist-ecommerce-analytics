-- Validate the customer-level 90-day repeat-purchase outcome

-- 1. Confirm one row per customer
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customer_repeat_90d;

-- 2. Find any customers who appear more than once
SELECT
    customer_unique_id,
    COUNT(*) AS row_count
FROM customer_repeat_90d
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

-- 3. Check the repeat-purchase target distribution
SELECT
    repeat_purchase_90d,
    COUNT(*) AS customers
FROM customer_repeat_90d
GROUP BY repeat_purchase_90d
ORDER BY repeat_purchase_90d;

-- 4. Find unexpected or NULL repeat-purchase target values
SELECT
    repeat_purchase_90d,
    COUNT(*) AS customers
FROM customer_repeat_90d
WHERE repeat_purchase_90d IS NULL
    OR repeat_purchase_90d NOT IN ('Yes', 'No')
GROUP BY repeat_purchase_90d
ORDER BY repeat_purchase_90d;

-- 5. Find negative repeat-order counts
SELECT
    customer_unique_id,
    repeat_orders_90d
FROM customer_repeat_90d
WHERE repeat_orders_90d < 0;

-- 6. Confirm that the repeat-order count and target agree
SELECT
    customer_unique_id,
    repeat_orders_90d,
    repeat_purchase_90d
FROM customer_repeat_90d
WHERE (repeat_orders_90d > 0 AND repeat_purchase_90d <> 'Yes')
    OR (repeat_orders_90d = 0 AND repeat_purchase_90d <> 'No')
    OR repeat_orders_90d IS NULL
    OR repeat_purchase_90d IS NULL;

-- 7. Confirm that every observation window ends after the first order
SELECT
    customer_unique_id,
    first_order_date,
    ninety_day_date
FROM customer_repeat_90d
WHERE first_order_date IS NULL
    OR ninety_day_date IS NULL
    OR first_order_date >= ninety_day_date;

-- 8. Confirm that every observation window is exactly 90 days long
SELECT
    customer_unique_id,
    first_order_date,
    ninety_day_date
FROM customer_repeat_90d
WHERE first_order_date IS NULL
    OR ninety_day_date IS NULL
    OR ninety_day_date <> first_order_date + INTERVAL '90 days';
