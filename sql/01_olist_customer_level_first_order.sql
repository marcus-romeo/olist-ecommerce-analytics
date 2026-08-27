-- Create the customer-level first-purchase dataset
DROP TABLE IF EXISTS customer_first_purchase;
CREATE TABLE customer_first_purchase AS
-- Choose one representative first order from each customer's earliest purchase
-- timestamp. When multiple orders share that timestamp, use order_id to select
-- one representative record. Same-timestamp orders are part of the
-- initial-purchase event and do not count as repeat orders.
WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        c.customer_zip_code_prefix,
        o.order_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS order_rank
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
),
-- Keep one representative record for each customer's initial purchase
first_orders AS (
    SELECT *
    FROM ranked_orders
    WHERE order_rank = 1
),
-- Gather product, seller, category, and order-value information
-- while keeping one row per first order
first_order_details AS (
    SELECT
        od.order_id,
        ARRAY_AGG(DISTINCT od.seller_id) AS seller_ids,
        COUNT(DISTINCT od.seller_id) AS number_of_sellers,
        ARRAY_AGG(DISTINCT od.product_id) AS product_ids,
        COUNT(od.product_id) AS products_ordered,
        COUNT(DISTINCT od.product_id) AS unique_products_ordered,
        ARRAY_AGG(DISTINCT COALESCE(pct.product_category_name_english, p.product_category_name)) FILTER (WHERE p.product_category_name IS NOT NULL) AS product_categories,
        COUNT(DISTINCT p.product_category_name) AS number_of_categories,
        SUM(od.price) AS product_amount,
        SUM(od.freight_value) AS freight_amount,
        SUM(od.price + od.freight_value) AS first_order_amount
    FROM order_details od
    JOIN first_orders f ON od.order_id = f.order_id
    LEFT JOIN products p ON od.product_id = p.product_id
    LEFT JOIN product_category_name_translation pct ON p.product_category_name = pct.product_category_name
    GROUP BY od.order_id
),
-- Gather payment information for each first order
first_order_payments AS (
    SELECT
        p.order_id,
        ARRAY_AGG(DISTINCT p.payment_type) AS payment_types,
        SUM(p.payment_value) AS total_payment_value,
        MAX(p.payment_installments) AS payment_installments
    FROM payments p
    JOIN first_orders f ON p.order_id = f.order_id
    GROUP BY p.order_id
),
-- Gather review information for each first order
first_order_reviews AS (
    SELECT
        r.order_id,
        AVG(r.review_score) AS review_score
    FROM reviews r
    JOIN first_orders f ON r.order_id = f.order_id
    GROUP BY r.order_id
)
-- Combine everything into one row per unique customer
SELECT
    f.customer_unique_id,
    f.customer_city,
    f.customer_state,
    f.customer_zip_code_prefix,
    f.order_id AS first_order_id,
    f.order_status AS first_order_status,
    f.order_purchase_timestamp AS first_order_date,
    fod.first_order_amount,
    fod.product_amount,
    fod.freight_amount,
    fod.products_ordered,
    fod.unique_products_ordered,
    fod.number_of_categories,
    fod.product_ids,
    fod.product_categories,
    fod.seller_ids,
    fod.number_of_sellers,
    fop.payment_types,
    fop.total_payment_value,
    fop.payment_installments,
    r.review_score,
    -- Calculate how many days it took to deliver the first order
    CASE
        WHEN f.order_delivered_customer_date IS NOT NULL
            THEN EXTRACT(DAY FROM (f.order_delivered_customer_date - f.order_purchase_timestamp))
        ELSE NULL
    END AS delivery_days,
    -- Calculate how many days early or late the delivery was
    -- Negative = early, 0 = on estimate, positive = late
    CASE
        WHEN f.order_delivered_customer_date IS NOT NULL
            AND f.order_estimated_delivery_date IS NOT NULL
            THEN EXTRACT(DAY FROM (f.order_delivered_customer_date - f.order_estimated_delivery_date))
        ELSE NULL
    END AS delivery_variance_days,
    -- Classify the delivery as On Time or Late
    CASE
        WHEN f.order_delivered_customer_date <= f.order_estimated_delivery_date THEN 'On Time'
        WHEN f.order_delivered_customer_date > f.order_estimated_delivery_date THEN 'Late'
        ELSE NULL
    END AS delivery_status
FROM first_orders f
LEFT JOIN first_order_details fod ON f.order_id = fod.order_id
LEFT JOIN first_order_payments fop ON f.order_id = fop.order_id
LEFT JOIN first_order_reviews r ON f.order_id = r.order_id;
