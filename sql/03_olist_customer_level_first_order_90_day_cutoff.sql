-- Create the 90-day-eligible customer cohort. Customers whose first order
-- occurred on or after the cutoff are excluded because the dataset does not
-- provide a complete 90-day outcome-observation period for them.
DROP TABLE IF EXISTS customer_first_purchase_90d;
CREATE TABLE customer_first_purchase_90d AS
SELECT *
FROM customer_first_purchase
WHERE first_order_date < '2018-07-20';
