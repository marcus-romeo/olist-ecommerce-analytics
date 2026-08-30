-- PURPOSE: Assemble the intermediate customer-level modeling dataset.
-- INPUTS: customer_repeat_90d, customer_first_purchase_90d.
-- OUTPUT: customer_modeling.
-- KEY BUSINESS RULE: This table keeps initial-event descriptors and the 90-day target at one
-- row per customer. Some retained descriptive fields are post-purchase and are intentionally
-- excluded by the final Model A table in the next stage.
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
    -- Freight burden is known from the initial event and is safe for Model A.
    CASE
        WHEN f.first_order_amount > 0
        THEN f.freight_amount / f.first_order_amount
        ELSE NULL
    END AS freight_to_order_ratio
FROM customer_repeat_90d r
JOIN customer_first_purchase_90d f
    ON r.customer_unique_id = f.customer_unique_id;
