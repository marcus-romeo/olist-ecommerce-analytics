-- PURPOSE: Validate the exact customer-specific 90-day outcome windows.
-- INPUTS: customer_90_day_windows.
-- OUTPUT: Read-only validation result sets.
-- KEY BUSINESS RULE: Every endpoint is exactly 90 days after the initial event and within source coverage.

SELECT
    COUNT(*) AS customers,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    MIN(first_order_date) AS earliest_initial_event,
    MAX(first_order_date) AS latest_initial_event,
    MIN(ninety_day_date) AS earliest_90_day_endpoint,
    MAX(ninety_day_date) AS latest_90_day_endpoint,
    MAX(observation_end_timestamp) AS observation_end_timestamp
FROM customer_90_day_windows;

-- Expected zero rows: the window table must retain one row per eligible customer.
SELECT customer_unique_id, COUNT(*) AS row_count
FROM customer_90_day_windows
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

-- Expected zero rows: invalid window length or right-censored observation window.
SELECT
    customer_unique_id,
    first_order_date,
    ninety_day_date,
    observation_end_timestamp
FROM customer_90_day_windows
WHERE ninety_day_date <> first_order_date + INTERVAL '90 days'
   OR ninety_day_date > observation_end_timestamp;
