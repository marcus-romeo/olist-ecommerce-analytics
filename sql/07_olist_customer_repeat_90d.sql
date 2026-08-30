-- PURPOSE: Build the customer-level 90-day repeat-purchase outcome.
-- INPUTS: customer_90_day_windows, customers, orders.
-- OUTPUT: customer_repeat_90d.
-- KEY BUSINESS RULE: A repeat is an order strictly after the complete initial-event timestamp
-- and on or before the customer's 90-day endpoint. Same-timestamp event orders are excluded.
-- LEAKAGE NOTE: All order statuses count because the target measures a placed order; this target
-- is never used as a predictor in Model A.

DROP TABLE IF EXISTS customer_repeat_90d;

CREATE TABLE customer_repeat_90d AS
SELECT
    w.customer_unique_id,
    w.first_order_date,
    w.ninety_day_date,
    COUNT(o.order_id) AS repeat_orders_90d,
    CASE
        WHEN COUNT(o.order_id) > 0 THEN 'Yes'
        ELSE 'No'
    END AS repeat_purchase_90d
FROM customer_90_day_windows w
LEFT JOIN customers c
    ON c.customer_unique_id = w.customer_unique_id
LEFT JOIN orders o
    ON o.customer_id = c.customer_id
   AND o.order_purchase_timestamp > w.first_order_date
   AND o.order_purchase_timestamp <= w.ninety_day_date
GROUP BY
    w.customer_unique_id,
    w.first_order_date,
    w.ninety_day_date;
