-- PURPOSE: Create the exact customer-specific 90-day observation window.
-- INPUTS: customer_first_purchase_90d.
-- OUTPUT: customer_90_day_windows.
-- OUTPUT GRAIN: One row per eligible customer_unique_id.
-- WORKFLOW STAGE: 5 of 15; materializes the inclusive endpoint used to build the target.
-- KEY BUSINESS RULE: The outcome window includes timestamps strictly after the initial event
-- and through the timestamp exactly 90 days later.

DROP TABLE IF EXISTS customer_90_day_windows;

CREATE TABLE customer_90_day_windows AS
-- Keep this narrow table separate so target logic has one explicit, auditable time boundary.
SELECT
    customer_unique_id,
    first_order_date,
    first_order_date + INTERVAL '90 days' AS ninety_day_date,
    observation_end_timestamp
FROM customer_first_purchase_90d;
