-- PURPOSE: Validate timestamp-precise 90-day eligibility.
-- INPUTS: customer_first_purchase_90d, orders.
-- OUTPUT: Read-only validation result sets.
-- KEY BUSINESS RULE: Each eligible event must end its 90-day window no later than the latest
-- observable raw order timestamp.

-- Show the derived raw-data observation boundary and retained cohort range.
SELECT
    MAX(observation_end_timestamp) AS observation_end_timestamp,
    MAX(eligibility_cutoff_timestamp) AS eligibility_cutoff_timestamp,
    COUNT(*) AS eligible_customers,
    MIN(first_order_date) AS earliest_initial_event,
    MAX(first_order_date) AS latest_initial_event
FROM customer_first_purchase_90d;

-- Expected zero rows: no retained event may extend beyond the raw observation endpoint.
SELECT
    customer_unique_id,
    first_order_date,
    first_order_date + INTERVAL '90 days' AS ninety_day_date,
    observation_end_timestamp
FROM customer_first_purchase_90d
WHERE first_order_date + INTERVAL '90 days' > observation_end_timestamp;

-- Expected zero rows: stored boundaries must continue to match the raw orders table.
SELECT DISTINCT
    f.observation_end_timestamp,
    f.eligibility_cutoff_timestamp,
    raw_boundary.observation_end_timestamp AS expected_observation_end_timestamp,
    raw_boundary.eligibility_cutoff_timestamp AS expected_eligibility_cutoff_timestamp
FROM customer_first_purchase_90d
    AS f
CROSS JOIN (
    SELECT
        MAX(order_purchase_timestamp) AS observation_end_timestamp,
        MAX(order_purchase_timestamp) - INTERVAL '90 days' AS eligibility_cutoff_timestamp
    FROM orders
) raw_boundary
WHERE f.observation_end_timestamp <> raw_boundary.observation_end_timestamp
   OR f.eligibility_cutoff_timestamp <> raw_boundary.eligibility_cutoff_timestamp;

-- Validate both directions of cohort membership. This guards against a valid-but-incomplete
-- cohort if a qualifying customer were accidentally omitted during the eligibility build.
WITH raw_boundary AS (
    SELECT
        MAX(order_purchase_timestamp) - INTERVAL '90 days' AS eligibility_cutoff_timestamp
    FROM orders
),
independently_eligible AS (
    SELECT f.customer_unique_id
    FROM customer_first_purchase f
    CROSS JOIN raw_boundary boundary
    WHERE f.first_order_date <= boundary.eligibility_cutoff_timestamp
),
cohort_comparison AS (
    SELECT
        COALESCE(eligible.customer_unique_id, cohort.customer_unique_id) AS customer_unique_id,
        eligible.customer_unique_id IS NOT NULL AS independently_eligible,
        cohort.customer_unique_id IS NOT NULL AS in_90_day_cohort
    FROM independently_eligible eligible
    FULL OUTER JOIN customer_first_purchase_90d cohort
        ON cohort.customer_unique_id = eligible.customer_unique_id
)
SELECT
    COUNT(*) FILTER (WHERE independently_eligible) AS independently_eligible_customers,
    COUNT(*) FILTER (WHERE in_90_day_cohort) AS customers_in_90_day_cohort,
    COUNT(*) FILTER (WHERE independently_eligible AND NOT in_90_day_cohort)
        AS eligible_customers_missing_from_cohort,
    COUNT(*) FILTER (WHERE in_90_day_cohort AND NOT independently_eligible)
        AS cohort_customers_not_independently_eligible
FROM cohort_comparison;
