-- PURPOSE: Validate the intermediate customer-level modeling dataset.
-- INPUTS: customer_modeling.
-- OUTPUT: Read-only validation result sets.
-- OUTPUT GRAIN: Aggregate checks, customer-level exceptions, and a schema inspection.
-- WORKFLOW STAGE: 10 of 15; validates the broad descriptive table before Model A removes leakage.
-- LEAKAGE NOTE: This intermediate table intentionally retains descriptive post-purchase fields;
-- the next Model A table excludes them before modeling.
-- PASSING RESULT: Grain and numerical exception checks should reconcile; NULLs are reported for later handling.

-- Confirm one row per customer_unique_id before a downstream modeling table is created.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customer_modeling;


-- Report the rare-target distribution that later informs metric interpretation.
SELECT
    repeat_purchase_90d,
    COUNT(*) AS customers,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM customer_modeling
GROUP BY repeat_purchase_90d
ORDER BY repeat_purchase_90d;


-- Report NULLs without treating them as automatic failures: their handling depends on the later model design.
SELECT
    COUNT(*) FILTER (WHERE customer_state IS NULL) AS customer_state_nulls,
    COUNT(*) FILTER (WHERE first_order_date IS NULL) AS first_order_date_nulls,
    COUNT(*) FILTER (WHERE first_order_status IS NULL) AS first_order_status_nulls,
    COUNT(*) FILTER (WHERE first_order_amount IS NULL) AS first_order_amount_nulls,
    COUNT(*) FILTER (WHERE product_amount IS NULL) AS product_amount_nulls,
    COUNT(*) FILTER (WHERE freight_amount IS NULL) AS freight_amount_nulls,
    COUNT(*) FILTER (WHERE products_ordered IS NULL) AS products_ordered_nulls,
    COUNT(*) FILTER (WHERE unique_products_ordered IS NULL) AS unique_products_nulls,
    COUNT(*) FILTER (WHERE number_of_categories IS NULL) AS category_nulls,
    COUNT(*) FILTER (WHERE number_of_sellers IS NULL) AS seller_nulls,
    COUNT(*) FILTER (WHERE payment_installments IS NULL) AS installment_nulls,
    COUNT(*) FILTER (WHERE review_score IS NULL) AS review_nulls,
    COUNT(*) FILTER (WHERE delivery_days IS NULL) AS delivery_days_nulls,
    COUNT(*) FILTER (WHERE delivery_variance_days IS NULL) AS delivery_variance_nulls,
    COUNT(*) FILTER (WHERE delivery_status IS NULL) AS delivery_status_nulls,
    COUNT(*) FILTER (WHERE freight_to_order_ratio IS NULL) AS freight_ratio_nulls
FROM customer_modeling;


-- Impossible values indicate a build or source-data issue; each count should be zero.
SELECT
    COUNT(*) FILTER (WHERE first_order_amount < 0) AS negative_order_amounts,
    COUNT(*) FILTER (WHERE product_amount < 0) AS negative_product_amounts,
    COUNT(*) FILTER (WHERE freight_amount < 0) AS negative_freight_amounts,
    COUNT(*) FILTER (WHERE products_ordered <= 0) AS invalid_product_counts,
    COUNT(*) FILTER (WHERE unique_products_ordered <= 0) AS invalid_unique_product_counts,
    COUNT(*) FILTER (WHERE number_of_categories <= 0) AS invalid_category_counts,
    COUNT(*) FILTER (WHERE number_of_sellers <= 0) AS invalid_seller_counts,
    COUNT(*) FILTER (WHERE payment_installments <= 0) AS invalid_installments,
    COUNT(*) FILTER (WHERE review_score < 1 OR review_score > 5) AS invalid_reviews,
    COUNT(*) FILTER (WHERE delivery_days < 0) AS negative_delivery_days
FROM customer_modeling;


-- Zero installments can be valid for some payment types, so inspect rather than silently discard them.
SELECT
    customer_unique_id,
    payment_installments,
    first_order_amount,
    repeat_purchase_90d
FROM customer_modeling
WHERE payment_installments <= 0;


-- Inspect the schema to make post-purchase columns visible before script 11 applies leakage exclusions.
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'customer_modeling'
ORDER BY ordinal_position;
