-- Create the initial purchase modeling dataset
-- Prediction point: immediately after the customer's first order is placed
-- Target: whether the customer places another order within 90 days
-- Retain only fields available at the initial-purchase prediction point.
-- Keep first_order_date to support chronological train/test splitting.
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
