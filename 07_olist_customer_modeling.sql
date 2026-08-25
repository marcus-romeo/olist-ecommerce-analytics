-- Create the final customer-level dataset for machine learning
-- Each row represents one customer
-- The predictor variables describe the customer's first order
-- repeat_purchase_90d is the outcome we are trying to predict
DROP TABLE IF EXISTS customer_modeling;
CREATE TABLE customer_modeling AS
SELECT
    r.customer_unique_id,
    r.repeat_purchase_90d,
    f.customer_state,
    f.first_order_date,
    f.first_order_status,
    f.first_order_amount,
    f.product_amount,
    f.freight_amount,
    f.products_ordered,
    f.unique_products_ordered,
    f.number_of_categories,
    f.number_of_sellers,
    f.payment_installments,
    f.review_score,
    f.delivery_days,
    f.delivery_variance_days,
    f.delivery_status,
    CASE
        WHEN f.first_order_amount > 0
        THEN f.freight_amount / f.first_order_amount
        ELSE NULL
    END AS freight_to_order_ratio
FROM customer_repeat_90d r
JOIN customer_first_purchase_90d f
    ON r.customer_unique_id = f.customer_unique_id;