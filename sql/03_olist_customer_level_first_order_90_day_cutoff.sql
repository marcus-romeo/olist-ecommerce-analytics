-- PURPOSE: Keep only customers with a fully observable 90-day repeat-purchase outcome.
-- INPUTS: customer_first_purchase, orders.
-- OUTPUT: customer_first_purchase_90d.
-- KEY BUSINESS RULE: Eligibility is timestamp-precise: initial event timestamp must be on or
-- before the latest observed order timestamp minus 90 days. The endpoint is derived from raw
-- orders each run so it cannot drift from the available observation period.

DROP TABLE IF EXISTS customer_first_purchase_90d;

CREATE TABLE customer_first_purchase_90d AS
WITH observation_boundary AS (
    SELECT
        MAX(order_purchase_timestamp) AS observation_end_timestamp,
        MAX(order_purchase_timestamp) - INTERVAL '90 days' AS eligibility_cutoff_timestamp
    FROM orders
)
SELECT
    f.*,
    boundary.observation_end_timestamp,
    boundary.eligibility_cutoff_timestamp
FROM customer_first_purchase f
CROSS JOIN observation_boundary boundary
WHERE f.first_order_date <= boundary.eligibility_cutoff_timestamp;
