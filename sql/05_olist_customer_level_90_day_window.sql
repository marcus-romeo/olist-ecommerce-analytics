-- Create each customer's individual observation window. The window ends
-- exactly 90 days after first_order_date.
DROP TABLE IF EXISTS customer_90_day_windows;
CREATE TABLE customer_90_day_windows AS
SELECT
    customer_unique_id,
    first_order_date,
    first_order_date + INTERVAL '90 days' AS ninety_day_date
FROM customer_first_purchase_90d;
