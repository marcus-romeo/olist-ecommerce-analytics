-- PURPOSE: Build one customer-level record for each customer's complete initial-purchase event.
-- INPUTS: customers, orders, order_details, payments, products, product_category_name_translation, reviews.
-- OUTPUT: customer_first_purchase.
-- KEY BUSINESS RULE: The initial-purchase event includes every order for a customer_unique_id
-- with that customer's earliest order_purchase_timestamp. Same-timestamp orders are part of
-- the initial event and therefore cannot be repeat orders.
-- LEAKAGE NOTE: This table retains some post-purchase fields for descriptive analysis only.
-- Model A later selects only prediction-time-safe fields in customer_initial_purchase_model.

BEGIN;

-- The source tables have no statistics for this reusable event CTE. Prevent the planner from
-- choosing a row-by-row nested-loop plan that repeatedly scans the full event during a rebuild.
-- LOCAL scope ends at COMMIT and does not change database-wide configuration.
SET LOCAL enable_nestloop = off;

DROP TABLE IF EXISTS customer_first_purchase;

CREATE TABLE customer_first_purchase AS
WITH customer_first_timestamps AS (
    -- Identify the customer-level event boundary before joining item or payment detail.
    SELECT
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_order_date
    FROM customers c
    JOIN orders o
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),
initial_event_orders AS (
    -- Retain every order at the earliest timestamp, rather than choosing one arbitrary order.
    SELECT
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        c.customer_zip_code_prefix,
        o.order_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM customer_first_timestamps ft
    JOIN customers c
        ON c.customer_unique_id = ft.customer_unique_id
    JOIN orders o
        ON o.customer_id = c.customer_id
       AND o.order_purchase_timestamp = ft.first_order_date
),
event_anchor_order AS (
    -- Keep a deterministic order-level anchor for customer geography and legacy descriptive fields.
    -- Item and payment features below still aggregate every order in the complete event.
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_id
        ) AS anchor_rank
    FROM initial_event_orders
),
event_metadata AS (
    -- Preserve event composition for auditing without changing Model A's predictor set.
    SELECT
        customer_unique_id,
        COUNT(*) AS initial_event_order_count,
        ARRAY_AGG(order_id ORDER BY order_id) AS initial_event_order_ids
    FROM initial_event_orders
    GROUP BY customer_unique_id
),
event_details AS (
    -- Aggregate item-level facts at customer/event grain. Missing category metadata is kept as
    -- an explicit unknown category instead of silently dropping it from category counts.
    SELECT
        ieo.customer_unique_id,
        ARRAY_AGG(DISTINCT od.seller_id ORDER BY od.seller_id) AS seller_ids,
        COUNT(DISTINCT od.seller_id) AS number_of_sellers,
        ARRAY_AGG(DISTINCT od.product_id ORDER BY od.product_id) AS product_ids,
        COUNT(od.product_id) AS products_ordered,
        COUNT(DISTINCT od.product_id) AS unique_products_ordered,
        ARRAY_AGG(
            DISTINCT COALESCE(
                pct.product_category_name_english,
                p.product_category_name,
                'unknown_product_category'
            )
            ORDER BY COALESCE(
                pct.product_category_name_english,
                p.product_category_name,
                'unknown_product_category'
            )
        ) AS product_categories,
        COUNT(
            DISTINCT COALESCE(
                pct.product_category_name_english,
                p.product_category_name,
                'unknown_product_category'
            )
        ) AS number_of_categories,
        SUM(od.price) AS product_amount,
        SUM(od.freight_value) AS freight_amount,
        SUM(od.price + od.freight_value) AS first_order_amount
    FROM initial_event_orders ieo
    JOIN order_details od
        ON od.order_id = ieo.order_id
    LEFT JOIN products p
        ON p.product_id = od.product_id
    LEFT JOIN product_category_name_translation pct
        ON pct.product_category_name = p.product_category_name
    GROUP BY ieo.customer_unique_id
),
event_payments AS (
    -- Payments are aggregated separately from items to avoid multiplying payment rows by items.
    SELECT
        ieo.customer_unique_id,
        ARRAY_AGG(DISTINCT p.payment_type ORDER BY p.payment_type) AS payment_types,
        SUM(p.payment_value) AS total_payment_value,
        MAX(p.payment_installments) AS payment_installments
    FROM initial_event_orders ieo
    JOIN payments p
        ON p.order_id = ieo.order_id
    GROUP BY ieo.customer_unique_id
),
event_reviews AS (
    -- Descriptive-only post-purchase field: average reviews across all orders in the event.
    SELECT
        ieo.customer_unique_id,
        AVG(r.review_score) AS review_score
    FROM initial_event_orders ieo
    JOIN reviews r
        ON r.order_id = ieo.order_id
    GROUP BY ieo.customer_unique_id
),
event_delivery AS (
    -- Descriptive-only post-purchase summaries across the complete initial event.
    SELECT
        customer_unique_id,
        AVG(
            EXTRACT(DAY FROM (order_delivered_customer_date - order_purchase_timestamp))
        ) FILTER (WHERE order_delivered_customer_date IS NOT NULL) AS delivery_days,
        AVG(
            EXTRACT(DAY FROM (order_delivered_customer_date - order_estimated_delivery_date))
        ) FILTER (
            WHERE order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
        ) AS delivery_variance_days,
        CASE
            WHEN BOOL_AND(
                order_delivered_customer_date IS NOT NULL
                AND order_estimated_delivery_date IS NOT NULL
                AND order_delivered_customer_date <= order_estimated_delivery_date
            ) THEN 'On Time'
            WHEN BOOL_OR(
                order_delivered_customer_date IS NOT NULL
                AND order_estimated_delivery_date IS NOT NULL
                AND order_delivered_customer_date > order_estimated_delivery_date
            ) THEN 'Late'
            ELSE NULL
        END AS delivery_status
    FROM initial_event_orders
    GROUP BY customer_unique_id
)
SELECT
    anchor.customer_unique_id,
    anchor.customer_city,
    anchor.customer_state,
    anchor.customer_zip_code_prefix,
    -- Retained legacy name: this is the deterministic anchor order within the full event.
    anchor.order_id AS first_order_id,
    anchor.order_status AS first_order_status,
    anchor.order_purchase_timestamp AS first_order_date,
    metadata.initial_event_order_count,
    metadata.initial_event_order_ids,
    details.first_order_amount,
    details.product_amount,
    details.freight_amount,
    details.products_ordered,
    details.unique_products_ordered,
    details.number_of_categories,
    details.product_ids,
    details.product_categories,
    details.seller_ids,
    details.number_of_sellers,
    payments.payment_types,
    payments.total_payment_value,
    payments.payment_installments,
    reviews.review_score,
    delivery.delivery_days,
    delivery.delivery_variance_days,
    delivery.delivery_status
FROM event_anchor_order anchor
JOIN event_metadata metadata
    ON metadata.customer_unique_id = anchor.customer_unique_id
LEFT JOIN event_details details
    ON details.customer_unique_id = anchor.customer_unique_id
LEFT JOIN event_payments payments
    ON payments.customer_unique_id = anchor.customer_unique_id
LEFT JOIN event_reviews reviews
    ON reviews.customer_unique_id = anchor.customer_unique_id
LEFT JOIN event_delivery delivery
    ON delivery.customer_unique_id = anchor.customer_unique_id
WHERE anchor.anchor_rank = 1;

COMMIT;
