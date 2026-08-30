-- PURPOSE: Build a richer, leakage-safe Model A dataset from the complete initial-purchase event.
-- INPUTS: customer_initial_purchase_model, customer_first_purchase_90d, order_details,
-- payments, products, sellers, geolocation, product_category_name_translation.
-- OUTPUT: customer_initial_purchase_model_enriched.
-- KEY BUSINESS RULE: Every feature uses only the customer's initial event and static product,
-- seller, or geographic metadata available at purchase time. No future performance, delivery,
-- review, approval, status, or target-derived information is included.
-- LEAKAGE NOTE: primary_category remains raw. Any rare-category grouping must be fitted inside
-- chronological model-training/validation preprocessing, never from the complete dataset.

DROP TABLE IF EXISTS customer_initial_purchase_model_enriched;

CREATE TABLE customer_initial_purchase_model_enriched AS
WITH zip_prefix_geography AS (
    -- The geolocation source has multiple coordinate records per ZIP prefix. Collapse it once
    -- so joining geography cannot multiply initial-event item rows.
    SELECT
        geolocation_zip_code_prefix AS zip_code_prefix,
        AVG(geolocation_lat) AS latitude,
        AVG(geolocation_lng) AS longitude
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
),
event_item_rows AS (
    -- Keep one row per item in every order at the complete initial-event timestamp. Customer
    -- geography comes from customer_first_purchase_90d's deterministic event anchor, never a
    -- later unrestricted customer_unique_id join.
    SELECT
        f.customer_unique_id,
        f.customer_state,
        f.customer_zip_code_prefix,
        od.product_id,
        od.seller_id,
        od.price,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm,
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'unknown_product_category'
        ) AS category,
        s.seller_state,
        customer_geo.latitude AS customer_latitude,
        customer_geo.longitude AS customer_longitude,
        seller_geo.latitude AS seller_latitude,
        seller_geo.longitude AS seller_longitude
    FROM customer_first_purchase_90d f
    LEFT JOIN order_details od
        ON od.order_id = ANY(f.initial_event_order_ids)
    LEFT JOIN products p
        ON p.product_id = od.product_id
    LEFT JOIN product_category_name_translation pct
        ON pct.product_category_name = p.product_category_name
    LEFT JOIN sellers s
        ON s.seller_id = od.seller_id
    LEFT JOIN zip_prefix_geography customer_geo
        ON customer_geo.zip_code_prefix = f.customer_zip_code_prefix
    LEFT JOIN zip_prefix_geography seller_geo
        ON seller_geo.zip_code_prefix = s.seller_zip_code_prefix
),
event_item_distances AS (
    -- Haversine distance is calculated at item grain. A later average is item-weighted, so an
    -- item appearing twice in the basket contributes twice to the basket's geographic exposure.
    SELECT
        *,
        CASE
            WHEN customer_latitude IS NOT NULL
             AND customer_longitude IS NOT NULL
             AND seller_latitude IS NOT NULL
             AND seller_longitude IS NOT NULL
            THEN 2.0 * 6371.0088 * ASIN(SQRT(LEAST(
                1.0,
                POWER(SIN(RADIANS((seller_latitude - customer_latitude) / 2.0)), 2)
                + COS(RADIANS(customer_latitude))
                  * COS(RADIANS(seller_latitude))
                  * POWER(SIN(RADIANS((seller_longitude - customer_longitude) / 2.0)), 2)
            )))
        END AS customer_seller_distance_km
    FROM event_item_rows
),
event_item_summary AS (
    -- Missing product/geocode metadata produces NULL rather than a partial total or partial
    -- distance. This makes missingness explicit for later training-only imputation decisions.
    SELECT
        customer_unique_id,
        CASE
            WHEN COUNT(product_id) > 0
             AND COUNT(product_id) = COUNT(product_weight_g)
            THEN SUM(product_weight_g)
        END AS total_product_weight_g,
        CASE
            WHEN COUNT(product_id) > 0
             AND COUNT(product_id) = COUNT(
                 CASE
                     WHEN product_length_cm IS NOT NULL
                      AND product_height_cm IS NOT NULL
                      AND product_width_cm IS NOT NULL
                     THEN 1
                 END
             )
            THEN SUM(
                product_length_cm::numeric
                * product_height_cm::numeric
                * product_width_cm::numeric
            )
        END AS total_product_volume_cm3,
        CASE
            WHEN COUNT(product_id) > 0
            THEN BOOL_OR(customer_state = seller_state)
        END AS any_seller_same_state,
        CASE
            WHEN COUNT(product_id) > 0
             AND COUNT(product_id) = COUNT(customer_seller_distance_km)
            THEN AVG(customer_seller_distance_km)
        END AS avg_customer_seller_distance_km
    FROM event_item_distances
    GROUP BY customer_unique_id
),
category_spend AS (
    -- Price share, not item count, defines the primary category. Ties are resolved alphabetically.
    SELECT
        customer_unique_id,
        category,
        SUM(price) AS category_price,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY SUM(price) DESC, category ASC
        ) AS category_rank
    FROM event_item_rows
    WHERE product_id IS NOT NULL
    GROUP BY customer_unique_id, category
),
primary_categories AS (
    SELECT
        customer_unique_id,
        category AS primary_category
    FROM category_spend
    WHERE category_rank = 1
),
event_payment_flags AS (
    -- Aggregate payment records independently of item rows to preserve their true event grain.
    SELECT
        f.customer_unique_id,
        COUNT(p.order_id) AS payment_record_count,
        BOOL_OR(p.payment_type = 'credit_card') AS has_credit_card,
        BOOL_OR(p.payment_type = 'boleto') AS has_boleto,
        BOOL_OR(p.payment_type = 'voucher') AS has_voucher,
        BOOL_OR(p.payment_type = 'debit_card') AS has_debit_card
    FROM customer_first_purchase_90d f
    LEFT JOIN payments p
        ON p.order_id = ANY(f.initial_event_order_ids)
    GROUP BY f.customer_unique_id
),
event_payments AS (
    -- The compact group distinguishes common channels while assigning uncommon combinations to
    -- Other instead of creating sparse combinations. Missing means no linked payment record.
    SELECT
        customer_unique_id,
        payment_record_count,
        CASE
            WHEN payment_record_count = 0 THEN 'missing'
            WHEN has_credit_card
             AND has_voucher
             AND NOT has_boleto
             AND NOT has_debit_card THEN 'credit_card_plus_voucher'
            WHEN has_credit_card
             AND NOT has_boleto
             AND NOT has_voucher
             AND NOT has_debit_card THEN 'credit_card'
            WHEN has_boleto
             AND NOT has_credit_card
             AND NOT has_voucher
             AND NOT has_debit_card THEN 'boleto'
            WHEN has_voucher
             AND NOT has_credit_card
             AND NOT has_boleto
             AND NOT has_debit_card THEN 'voucher'
            WHEN has_debit_card
             AND NOT has_credit_card
             AND NOT has_boleto
             AND NOT has_voucher THEN 'debit_card'
            ELSE 'other'
        END AS payment_type_group
    FROM event_payment_flags
)
SELECT
    -- Select the corrected original table first so customer and target parity is intentional.
    original.*,
    COALESCE(primary_categories.primary_category, 'missing_order_details') AS primary_category,
    payments.payment_type_group,
    payments.payment_record_count,
    EXTRACT(MONTH FROM original.first_order_date)::smallint AS first_order_month,
    -- ISO weekday convention: 1 = Monday through 7 = Sunday.
    EXTRACT(ISODOW FROM original.first_order_date)::smallint AS first_order_weekday,
    item_summary.total_product_weight_g,
    item_summary.total_product_volume_cm3,
    item_summary.any_seller_same_state,
    item_summary.avg_customer_seller_distance_km
FROM customer_initial_purchase_model original
JOIN customer_first_purchase_90d f
    ON f.customer_unique_id = original.customer_unique_id
LEFT JOIN event_item_summary item_summary
    ON item_summary.customer_unique_id = original.customer_unique_id
LEFT JOIN primary_categories
    ON primary_categories.customer_unique_id = original.customer_unique_id
LEFT JOIN event_payments payments
    ON payments.customer_unique_id = original.customer_unique_id;
