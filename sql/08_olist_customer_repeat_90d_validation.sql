-- PURPOSE: Validate the 90-day repeat-purchase target.
-- INPUTS: customer_repeat_90d, customer_90_day_windows, customers, orders.
-- OUTPUT: Read-only validation result sets.
-- OUTPUT GRAIN: Aggregate target summaries and customer-level target exceptions.
-- WORKFLOW STAGE: 8 of 15; confirms the target before it is joined to features.
-- KEY BUSINESS RULE: Repeat orders are strictly after the initial timestamp and on/before day 90.
-- PASSING RESULT: Expected-zero exception queries return no rows and strict raw recomputation matches.

SELECT
    repeat_purchase_90d,
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS percentage
FROM customer_repeat_90d
GROUP BY repeat_purchase_90d
ORDER BY repeat_purchase_90d;

-- Expected zero rows: target grain or binary-label violations.
SELECT customer_unique_id, COUNT(*) AS row_count
FROM customer_repeat_90d
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

SELECT customer_unique_id, repeat_orders_90d, repeat_purchase_90d
FROM customer_repeat_90d
WHERE repeat_purchase_90d NOT IN ('Yes', 'No')
   OR repeat_purchase_90d IS NULL
   OR (repeat_orders_90d > 0 AND repeat_purchase_90d <> 'Yes')
   OR (repeat_orders_90d = 0 AND repeat_purchase_90d <> 'No');

-- Report eligible multi-order initial events. The strict recomputation below verifies that none
-- of these same-timestamp orders were included in repeat_orders_90d.
SELECT
    COUNT(*) FILTER (WHERE f.initial_event_order_count > 1) AS eligible_multi_order_initial_events,
    MAX(f.initial_event_order_count) AS max_orders_in_eligible_initial_event
FROM customer_first_purchase_90d f;

-- Recompute counts with the strict target boundary; expected zero rows.
WITH recomputed AS (
    -- Rebuild counts from raw orders rather than trusting the stored target calculation.
    SELECT
        w.customer_unique_id,
        COUNT(o.order_id) AS expected_repeat_orders_90d
    FROM customer_90_day_windows w
    LEFT JOIN customers c
        ON c.customer_unique_id = w.customer_unique_id
    LEFT JOIN orders o
        ON o.customer_id = c.customer_id
       AND o.order_purchase_timestamp > w.first_order_date
       AND o.order_purchase_timestamp <= w.ninety_day_date
    GROUP BY w.customer_unique_id
)
SELECT
    r.customer_unique_id,
    r.repeat_orders_90d,
    recomputed.expected_repeat_orders_90d
FROM customer_repeat_90d r
JOIN recomputed
    ON recomputed.customer_unique_id = r.customer_unique_id
WHERE r.repeat_orders_90d <> recomputed.expected_repeat_orders_90d;
