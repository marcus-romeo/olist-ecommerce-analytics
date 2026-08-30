-- PURPOSE: Validate the corrected original eight-feature Model A dataset.
-- INPUTS: customer_initial_purchase_model, customer_first_purchase_90d.
-- OUTPUT: Read-only validation result sets.
-- OUTPUT GRAIN: Aggregate dataset summaries and customer-level exception rows.
-- WORKFLOW STAGE: 12 of 15; confirms the Original 8 source table before baseline notebooks use it.
-- LEAKAGE RULE: This final Model A table may contain only the stated initial-event predictors,
-- target, customer identifier, and timestamp retained for chronological splitting.
-- PASSING RESULT: Expected-zero exception queries return no rows; missingness is reported transparently.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    MIN(first_order_date) AS earliest_initial_event,
    MAX(first_order_date) AS latest_initial_event
FROM customer_initial_purchase_model;

-- Expected zero rows: duplicate customer grain violations.
SELECT customer_unique_id, COUNT(*) AS row_count
FROM customer_initial_purchase_model
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

SELECT
    repeat_purchase_90d,
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS percentage
FROM customer_initial_purchase_model
GROUP BY repeat_purchase_90d
ORDER BY repeat_purchase_90d;

SELECT
    COUNT(*) FILTER (WHERE customer_state IS NULL) AS customer_state_nulls,
    COUNT(*) FILTER (WHERE first_order_amount IS NULL) AS order_amount_nulls,
    COUNT(*) FILTER (WHERE product_amount IS NULL) AS product_amount_nulls,
    COUNT(*) FILTER (WHERE freight_amount IS NULL) AS freight_amount_nulls,
    COUNT(*) FILTER (WHERE products_ordered IS NULL) AS product_count_nulls,
    COUNT(*) FILTER (WHERE unique_products_ordered IS NULL) AS unique_product_count_nulls,
    COUNT(*) FILTER (WHERE number_of_categories IS NULL) AS category_count_nulls,
    COUNT(*) FILTER (WHERE number_of_sellers IS NULL) AS seller_count_nulls,
    COUNT(*) FILTER (WHERE payment_installments IS NULL) AS installment_nulls,
    COUNT(*) FILTER (WHERE freight_to_order_ratio IS NULL) AS freight_ratio_nulls
FROM customer_initial_purchase_model;

-- Expected zero rows: impossible initial-event amounts, counts, or freight ratios.
SELECT *
FROM customer_initial_purchase_model
WHERE first_order_amount < 0
   OR product_amount < 0
   OR freight_amount < 0
   OR products_ordered <= 0
   OR unique_products_ordered <= 0
   OR unique_products_ordered > products_ordered
   OR number_of_categories <= 0
   OR number_of_sellers <= 0
   OR payment_installments < 0
   OR freight_to_order_ratio < 0
   OR freight_to_order_ratio > 1;

-- Expected zero rows: post-purchase fields must not enter the original Model A table.
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'customer_initial_purchase_model'
  AND column_name IN (
      'first_order_status',
      'review_score',
      'delivery_days',
      'delivery_variance_days',
      'delivery_status',
      'order_approved_at',
      'order_delivered_customer_date',
      'shipping_limit_date',
      'payment_value'
  );
