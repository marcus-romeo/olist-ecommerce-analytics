-- PURPOSE: Validate the enriched, leakage-safe Model A feature table and its parity with the
-- corrected original eight-feature table.
-- INPUTS: customer_initial_purchase_model, customer_initial_purchase_model_enriched.
-- OUTPUT: Read-only validation result sets.
-- LEAKAGE RULE: New fields must describe only the complete initial event and static metadata.

-- Confirm exact customer and target parity between the original and enriched feature tables.
WITH population_comparison AS (
    SELECT
        COALESCE(original.customer_unique_id, enriched.customer_unique_id) AS customer_unique_id,
        original.repeat_purchase_90d AS original_target,
        enriched.repeat_purchase_90d AS enriched_target,
        original.customer_unique_id IS NOT NULL AS in_original,
        enriched.customer_unique_id IS NOT NULL AS in_enriched
    FROM customer_initial_purchase_model original
    FULL OUTER JOIN customer_initial_purchase_model_enriched enriched
        ON enriched.customer_unique_id = original.customer_unique_id
)
SELECT
    COUNT(*) AS customers_in_comparison,
    COUNT(*) FILTER (WHERE NOT in_original) AS enriched_only_customers,
    COUNT(*) FILTER (WHERE NOT in_enriched) AS original_only_customers,
    COUNT(*) FILTER (WHERE original_target IS DISTINCT FROM enriched_target) AS target_mismatches
FROM population_comparison;

-- Expected zero rows: duplicate customer grain violations.
SELECT customer_unique_id, COUNT(*) AS row_count
FROM customer_initial_purchase_model_enriched
GROUP BY customer_unique_id
HAVING COUNT(*) > 1;

-- Missingness is reported explicitly because model preprocessing, not SQL, should choose imputation.
SELECT
    COUNT(*) FILTER (WHERE primary_category IS NULL) AS primary_category_nulls,
    COUNT(*) FILTER (WHERE payment_type_group IS NULL) AS payment_type_group_nulls,
    COUNT(*) FILTER (WHERE payment_record_count IS NULL) AS payment_record_count_nulls,
    COUNT(*) FILTER (WHERE first_order_month IS NULL) AS first_order_month_nulls,
    COUNT(*) FILTER (WHERE first_order_weekday IS NULL) AS first_order_weekday_nulls,
    COUNT(*) FILTER (WHERE total_product_weight_g IS NULL) AS total_product_weight_nulls,
    COUNT(*) FILTER (WHERE total_product_volume_cm3 IS NULL) AS total_product_volume_nulls,
    COUNT(*) FILTER (WHERE any_seller_same_state IS NULL) AS any_seller_same_state_nulls,
    COUNT(*) FILTER (WHERE avg_customer_seller_distance_km IS NULL) AS distance_nulls
FROM customer_initial_purchase_model_enriched;

-- Raw category is intentionally preserved. Frequency grouping belongs inside future train-only preprocessing.
SELECT
    primary_category,
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS percentage
FROM customer_initial_purchase_model_enriched
GROUP BY primary_category
ORDER BY customers DESC, primary_category;

SELECT
    payment_type_group,
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS percentage
FROM customer_initial_purchase_model_enriched
GROUP BY payment_type_group
ORDER BY customers DESC, payment_type_group;

SELECT payment_record_count, COUNT(*) AS customers
FROM customer_initial_purchase_model_enriched
GROUP BY payment_record_count
ORDER BY payment_record_count;

-- Expected zero rows: invalid calendar, physical-basket, seller-state, or distance values.
SELECT *
FROM customer_initial_purchase_model_enriched
WHERE first_order_month NOT BETWEEN 1 AND 12
   OR first_order_weekday NOT BETWEEN 1 AND 7
   OR payment_record_count < 0
   OR total_product_weight_g < 0
   OR total_product_volume_cm3 < 0
   OR avg_customer_seller_distance_km < 0
   OR avg_customer_seller_distance_km > 20040;

SELECT
    any_seller_same_state,
    COUNT(*) AS customers
FROM customer_initial_purchase_model_enriched
GROUP BY any_seller_same_state
ORDER BY any_seller_same_state;

SELECT
    COUNT(*) FILTER (WHERE avg_customer_seller_distance_km IS NOT NULL) AS geocoded_customers,
    COUNT(*) FILTER (WHERE avg_customer_seller_distance_km IS NULL) AS customers_with_incomplete_geocodes,
    ROUND(MIN(avg_customer_seller_distance_km)::numeric, 2) AS min_distance_km,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_customer_seller_distance_km)::numeric, 2) AS median_distance_km,
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY avg_customer_seller_distance_km)::numeric, 2) AS p90_distance_km,
    ROUND(MAX(avg_customer_seller_distance_km)::numeric, 2) AS max_distance_km
FROM customer_initial_purchase_model_enriched;

-- Expected zero rows: explicitly prohibited post-purchase, raw-ID, or future-derived columns.
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'customer_initial_purchase_model_enriched'
  AND column_name IN (
      'first_order_status',
      'review_score',
      'delivery_days',
      'delivery_variance_days',
      'delivery_status',
      'order_approved_at',
      'order_delivered_customer_date',
      'shipping_limit_date',
      'payment_value',
      'customer_city',
      'customer_zip_code_prefix',
      'product_id',
      'seller_id',
      'seller_city'
  );

-- Reconstruct primary category from raw initial-event item rows. Category price contribution is
-- summed across every event order; alphabetical ordering resolves an exact price tie. Events
-- without item detail must retain the explicit missing_order_details category.
WITH event_category_spend AS (
    SELECT
        f.customer_unique_id,
        COALESCE(
            translation.product_category_name_english,
            product.product_category_name,
            'unknown_product_category'
        ) AS category,
        SUM(item.price) AS category_price
    FROM customer_first_purchase_90d f
    CROSS JOIN LATERAL UNNEST(f.initial_event_order_ids) AS event_order(order_id)
    JOIN order_details item
        ON item.order_id = event_order.order_id
    LEFT JOIN products product
        ON product.product_id = item.product_id
    LEFT JOIN product_category_name_translation translation
        ON translation.product_category_name = product.product_category_name
    GROUP BY
        f.customer_unique_id,
        COALESCE(
            translation.product_category_name_english,
            product.product_category_name,
            'unknown_product_category'
        )
),
ranked_categories AS (
    SELECT
        customer_unique_id,
        category,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY category_price DESC, category ASC
        ) AS category_rank
    FROM event_category_spend
)
SELECT
    COUNT(*) FILTER (
        WHERE COALESCE(ranked.category, 'missing_order_details')
            IS DISTINCT FROM enriched.primary_category
    ) AS primary_category_mismatches
FROM customer_initial_purchase_model_enriched enriched
LEFT JOIN ranked_categories ranked
    ON ranked.customer_unique_id = enriched.customer_unique_id
   AND ranked.category_rank = 1;

-- Recount raw payment rows across every order in the complete initial event. This is separate
-- from item aggregation so payment-record validation cannot be affected by basket row counts.
WITH raw_event_payment_counts AS (
    SELECT
        f.customer_unique_id,
        COUNT(payment.order_id) AS expected_payment_record_count
    FROM customer_first_purchase_90d f
    LEFT JOIN LATERAL UNNEST(f.initial_event_order_ids) AS event_order(order_id)
        ON TRUE
    LEFT JOIN payments payment
        ON payment.order_id = event_order.order_id
    GROUP BY f.customer_unique_id
)
SELECT
    COUNT(*) FILTER (
        WHERE enriched.payment_record_count <> raw.expected_payment_record_count
    ) AS payment_record_count_mismatches
FROM customer_initial_purchase_model_enriched enriched
JOIN raw_event_payment_counts raw
    ON raw.customer_unique_id = enriched.customer_unique_id;

-- Independently reproduce the documented item-weighted Haversine distance. ZIP-prefix source
-- rows are first averaged to prevent geolocation duplicates from changing the item grain. As in
-- the build, any missing item-level geocode yields NULL for the entire event distance.
WITH zip_prefix_geography AS (
    SELECT
        geolocation_zip_code_prefix AS zip_code_prefix,
        AVG(geolocation_lat) AS latitude,
        AVG(geolocation_lng) AS longitude
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
),
raw_event_item_distances AS (
    SELECT
        f.customer_unique_id,
        item.product_id,
        CASE
            WHEN customer_geo.latitude IS NOT NULL
             AND customer_geo.longitude IS NOT NULL
             AND seller_geo.latitude IS NOT NULL
             AND seller_geo.longitude IS NOT NULL
            THEN 2.0 * 6371.0088 * ASIN(SQRT(LEAST(
                1.0,
                POWER(SIN(RADIANS((seller_geo.latitude - customer_geo.latitude) / 2.0)), 2)
                + COS(RADIANS(customer_geo.latitude))
                  * COS(RADIANS(seller_geo.latitude))
                  * POWER(SIN(RADIANS((seller_geo.longitude - customer_geo.longitude) / 2.0)), 2)
            )))
        END AS item_distance_km
    FROM customer_first_purchase_90d f
    LEFT JOIN LATERAL UNNEST(f.initial_event_order_ids) AS event_order(order_id)
        ON TRUE
    LEFT JOIN order_details item
        ON item.order_id = event_order.order_id
    LEFT JOIN sellers seller
        ON seller.seller_id = item.seller_id
    LEFT JOIN zip_prefix_geography customer_geo
        ON customer_geo.zip_code_prefix = f.customer_zip_code_prefix
    LEFT JOIN zip_prefix_geography seller_geo
        ON seller_geo.zip_code_prefix = seller.seller_zip_code_prefix
),
raw_event_distances AS (
    SELECT
        customer_unique_id,
        CASE
            WHEN COUNT(product_id) > 0
             AND COUNT(product_id) = COUNT(item_distance_km)
            THEN AVG(item_distance_km)
        END AS expected_avg_customer_seller_distance_km
    FROM raw_event_item_distances
    GROUP BY customer_unique_id
)
SELECT
    COUNT(*) FILTER (
        WHERE (raw.expected_avg_customer_seller_distance_km IS NULL
               AND enriched.avg_customer_seller_distance_km IS NOT NULL)
           OR (raw.expected_avg_customer_seller_distance_km IS NOT NULL
               AND enriched.avg_customer_seller_distance_km IS NULL)
           OR ABS(
               raw.expected_avg_customer_seller_distance_km
               - enriched.avg_customer_seller_distance_km
           ) > 0.000001
    ) AS customer_seller_distance_mismatches
FROM customer_initial_purchase_model_enriched enriched
JOIN raw_event_distances raw
    ON raw.customer_unique_id = enriched.customer_unique_id;
