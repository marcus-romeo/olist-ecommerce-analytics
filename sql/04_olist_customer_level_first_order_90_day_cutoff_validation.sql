-- Check the number of customers and the first-order date range
SELECT
    COUNT(*) AS customers,
    MIN(first_order_date) AS earliest_first_order,
    MAX(first_order_date) AS latest_first_order
FROM customer_first_purchase_90d;
-- Confirm that no customers with a first order on or after the cutoff
-- were included in the 90-day modeling dataset
SELECT COUNT(*) AS customers_after_cutoff
FROM customer_first_purchase_90d
WHERE first_order_date >= '2018-07-20';
