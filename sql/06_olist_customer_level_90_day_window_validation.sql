-- Check the number of customers and the range of their individual 90-day windows
SELECT
    COUNT(*) AS customers,
    MIN(first_order_date) AS earliest_first_order,
    MAX(first_order_date) AS latest_first_order,
    MIN(ninety_day_date) AS earliest_90_day_date,
    MAX(ninety_day_date) AS latest_90_day_date
FROM customer_90_day_windows;
-- Look at some individual customers and their 90-day windows
SELECT *
FROM customer_90_day_windows
ORDER BY first_order_date
LIMIT 20;
