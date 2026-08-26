-- Create a modeling dataset by excluding customers whose first order
-- occurred during the final 90 days of the Olist timeline
DROP TABLE IF EXISTS customer_first_purchase_90d;
CREATE TABLE customer_first_purchase_90d AS
SELECT *
FROM customer_first_purchase
WHERE first_order_date < '2018-07-20';
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
