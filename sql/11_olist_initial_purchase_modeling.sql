-- PURPOSE: Build the corrected original Model A feature table with the established eight predictors.
-- INPUTS: customer_modeling.
-- OUTPUT: customer_initial_purchase_model.
-- KEY BUSINESS RULE: Features represent the complete initial-purchase event; first_order_date is
-- retained only for chronological splitting. Post-purchase status, review, and delivery fields
-- are deliberately excluded to prevent leakage.
DROP TABLE IF EXISTS customer_initial_purchase_model;
CREATE TABLE customer_initial_purchase_model AS
SELECT
    customer_unique_id,
    repeat_purchase_90d,
    customer_state,
    first_order_date,
    first_order_amount,
    product_amount,
    freight_amount,
    products_ordered,
    unique_products_ordered,
    number_of_categories,
    number_of_sellers,
    payment_installments,
    freight_to_order_ratio
FROM customer_modeling;
