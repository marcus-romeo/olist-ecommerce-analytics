-- Create the customer-level 90-day repeat-purchase outcome. A repeat purchase
-- means at least one later order with a timestamp strictly greater than
-- first_order_date and less than or equal to ninety_day_date. Same-timestamp
-- orders are excluded. All order statuses count because the business definition
-- is that the customer placed another order.

DROP TABLE IF EXISTS customer_repeat_90d;
CREATE TABLE customer_repeat_90d AS
SELECT
    w.customer_unique_id,
    f.first_order_date,
    w.ninety_day_date,
    COUNT(o.order_id) AS repeat_orders_90d,
    CASE
        WHEN COUNT(o.order_id) > 0 THEN 'Yes'
        ELSE 'No'
    END AS repeat_purchase_90d
FROM customer_90_day_windows w
JOIN customer_first_purchase_90d f
    ON w.customer_unique_id = f.customer_unique_id
LEFT JOIN customers c
    ON w.customer_unique_id = c.customer_unique_id
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
    AND o.order_purchase_timestamp > f.first_order_date
    AND o.order_purchase_timestamp <= w.ninety_day_date
GROUP BY
    w.customer_unique_id,
    f.first_order_date,
    w.ninety_day_date;
