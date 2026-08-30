-- PURPOSE: Validate customer_first_purchase at the complete initial-event grain.
-- INPUTS: customer_first_purchase, customers, orders.
-- OUTPUT: Read-only validation result sets.
-- KEY BUSINESS RULES: Exactly one event per customer; every and only earliest-timestamp order
-- belongs to that event. Delivery and review fields are descriptive only, not Model A inputs.

-- Confirm customer grain and quantify multi-order same-timestamp initial events.
SELECT
    COUNT(*) AS customer_events,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    COUNT(*) FILTER (WHERE initial_event_order_count > 1) AS multi_order_initial_events,
    MAX(initial_event_order_count) AS max_orders_in_initial_event
FROM customer_first_purchase;

-- Return any grain violations; expected result is zero rows.
SELECT customer_unique_id, COUNT(*) AS row_count
FROM customer_first_purchase
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

-- Verify stored event order counts equal the raw count of orders at each customer's minimum timestamp.
WITH expected_events AS (
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id) AS expected_initial_event_order_count
    FROM customers c
    JOIN orders o
        ON o.customer_id = c.customer_id
    JOIN (
        SELECT
            c.customer_unique_id,
            MIN(o.order_purchase_timestamp) AS first_order_date
        FROM customers c
        JOIN orders o
            ON o.customer_id = c.customer_id
        GROUP BY c.customer_unique_id
    ) first_times
        ON first_times.customer_unique_id = c.customer_unique_id
       AND first_times.first_order_date = o.order_purchase_timestamp
    GROUP BY c.customer_unique_id
)
SELECT
    f.customer_unique_id,
    f.initial_event_order_count,
    e.expected_initial_event_order_count
FROM customer_first_purchase f
JOIN expected_events e
    ON e.customer_unique_id = f.customer_unique_id
WHERE f.initial_event_order_count <> e.expected_initial_event_order_count;

-- Confirm no order after the event timestamp was accidentally retained in event order IDs.
SELECT
    f.customer_unique_id,
    event_order_id,
    o.order_purchase_timestamp,
    f.first_order_date
FROM customer_first_purchase f
CROSS JOIN LATERAL UNNEST(f.initial_event_order_ids) AS event_order_id
JOIN orders o
    ON o.order_id = event_order_id
WHERE o.order_purchase_timestamp <> f.first_order_date;

-- customer_first_purchase retains one deterministic anchor order for customer geography while
-- aggregating all initial-event orders for basket features. For multi-order events, confirm that
-- the anchor cannot arbitrarily select between conflicting order-level customer locations.
WITH customer_first_timestamps AS (
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_order_date
    FROM customers c
    JOIN orders o
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),
multi_order_event_geography AS (
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id) AS initial_event_order_count,
        COUNT(DISTINCT c.customer_state) AS state_count,
        COUNT(DISTINCT c.customer_city) AS city_count,
        COUNT(DISTINCT c.customer_zip_code_prefix) AS zip_prefix_count
    FROM customer_first_timestamps ft
    JOIN customers c
        ON c.customer_unique_id = ft.customer_unique_id
    JOIN orders o
        ON o.customer_id = c.customer_id
       AND o.order_purchase_timestamp = ft.first_order_date
    GROUP BY c.customer_unique_id
    HAVING COUNT(o.order_id) > 1
)
SELECT
    COUNT(*) AS multi_order_initial_events,
    COUNT(*) FILTER (WHERE state_count > 1) AS conflicting_state_events,
    COUNT(*) FILTER (WHERE city_count > 1) AS conflicting_city_events,
    COUNT(*) FILTER (WHERE zip_prefix_count > 1) AS conflicting_zip_prefix_events
FROM multi_order_event_geography;

-- Report essential missingness and numerical ranges for the customer-level event table.
SELECT
    COUNT(*) FILTER (WHERE first_order_amount IS NULL) AS order_amount_nulls,
    COUNT(*) FILTER (WHERE products_ordered IS NULL) AS product_count_nulls,
    COUNT(*) FILTER (WHERE payment_installments IS NULL) AS installment_nulls,
    COUNT(*) FILTER (WHERE customer_state IS NULL) AS customer_state_nulls,
    MIN(first_order_date) AS earliest_initial_event,
    MAX(first_order_date) AS latest_initial_event,
    MIN(first_order_amount) AS min_event_amount,
    MAX(first_order_amount) AS max_event_amount
FROM customer_first_purchase;
