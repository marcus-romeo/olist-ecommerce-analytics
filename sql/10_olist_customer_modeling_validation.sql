-- PURPOSE: Validate the intermediate customer-level modeling dataset.
-- INPUTS: customer_modeling.
-- OUTPUT: Read-only validation result sets.
-- LEAKAGE NOTE: This intermediate table intentionally retains descriptive post-purchase fields;
-- the next Model A table excludes them before modeling.

-- VALIDATION 1: Confirm one row per customer
-- Total rows should equal unique customers
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customer_modeling;


-- VALIDATION 2: Confirm the target variable distribution
-- This verifies the number and percentage of returning vs non-returning customers
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


-- VALIDATION 3: Check for NULL values in the modeling variables
-- NULLs are not automatically errors and will be handled during model preprocessing
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


-- VALIDATION 4: Check for potentially invalid numeric values
-- Ideally, all results should be zero
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


-- VALIDATION 5: Inspect customers with zero payment installments
-- These records are investigated rather than automatically removed
SELECT
    customer_unique_id,
    payment_installments,
    first_order_amount,
    repeat_purchase_90d
FROM customer_modeling
WHERE payment_installments <= 0;


-- VALIDATION 6: Review the structure of the intermediate modeling dataset
-- This helps identify variables that may contain information unavailable at prediction time
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'customer_modeling'
ORDER BY ordinal_position;
