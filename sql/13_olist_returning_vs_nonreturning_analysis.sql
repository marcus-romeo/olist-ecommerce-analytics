-- PURPOSE: Explore descriptive differences between returning and non-returning customers.
-- INPUTS: customer_repeat_90d, customer_first_purchase_90d.
-- OUTPUT: Read-only descriptive result sets.
-- LEAKAGE NOTE: Review and delivery comparisons are post-outcome descriptive analysis only;
-- they are explicitly not sources of Model A predictors.

-- Compare the number of returning and non-returning customers
SELECT
    repeat_purchase_90d,
    COUNT(*) AS customers
FROM customer_repeat_90d
GROUP BY repeat_purchase_90d
ORDER BY repeat_purchase_90d;


-- Compare the percentage of returning vs non-returning customers who gave a 5-star review among customers who left a review
SELECT
    r.repeat_purchase_90d,
    COUNT(f.review_score) AS customers_with_reviews,
    COUNT(*) FILTER (WHERE f.review_score = 5) AS five_star_reviews,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE f.review_score = 5) / COUNT(f.review_score),
        2
    ) AS five_star_percentage
FROM customer_repeat_90d r
JOIN customer_first_purchase_90d f
    ON r.customer_unique_id = f.customer_unique_id
WHERE f.review_score IS NOT NULL
GROUP BY r.repeat_purchase_90d
ORDER BY r.repeat_purchase_90d;


-- Compare the percentage of returning vs non-returning customers who gave a 5-star review
SELECT
    r.repeat_purchase_90d,
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (WHERE f.review_score = 5) AS five_star_reviews,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE f.review_score = 5) / COUNT(*),
        2
    ) AS five_star_percentage
FROM customer_repeat_90d r
JOIN customer_first_purchase_90d f
    ON r.customer_unique_id = f.customer_unique_id
GROUP BY r.repeat_purchase_90d
ORDER BY r.repeat_purchase_90d;


-- Compare the percentage of returning vs non-returning customers whose first order was delivered on time
SELECT
    r.repeat_purchase_90d,
    COUNT(f.delivery_status) AS customers_with_delivery_status,
    COUNT(*) FILTER (WHERE f.delivery_status = 'On Time') AS delivered_on_time,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE f.delivery_status = 'On Time') / COUNT(f.delivery_status),
        2
    ) AS on_time_percentage
FROM customer_repeat_90d r
JOIN customer_first_purchase_90d f
    ON r.customer_unique_id = f.customer_unique_id
WHERE f.delivery_status IS NOT NULL
GROUP BY r.repeat_purchase_90d
ORDER BY r.repeat_purchase_90d;


-- Compare the percentage of returning vs non-returning customers whose first order included each product category
WITH customer_categories AS (
    SELECT DISTINCT
        r.customer_unique_id,
        r.repeat_purchase_90d,
        category
    FROM customer_repeat_90d r
    JOIN customer_first_purchase_90d f
        ON r.customer_unique_id = f.customer_unique_id
    CROSS JOIN LATERAL unnest(f.product_categories) AS category
),
category_counts AS (
    SELECT
        repeat_purchase_90d,
        category,
        COUNT(*) AS customers
    FROM customer_categories
    GROUP BY
        repeat_purchase_90d,
        category
),
group_totals AS (
    SELECT
        repeat_purchase_90d,
        COUNT(DISTINCT customer_unique_id) AS total_customers
    FROM customer_categories
    GROUP BY repeat_purchase_90d
)
SELECT
    c.repeat_purchase_90d,
    c.category,
    c.customers,
    ROUND(
        100.0 * c.customers / g.total_customers,
        2
    ) AS percentage_of_customers
FROM category_counts c
JOIN group_totals g
    ON c.repeat_purchase_90d = g.repeat_purchase_90d
ORDER BY
    c.repeat_purchase_90d,
    percentage_of_customers DESC;


-- Compare the percentage of returning vs non-returning customers whose first order exceeded different dollar amounts
SELECT
    r.repeat_purchase_90d,
    COUNT(*) AS total_customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE f.first_order_amount > 25) / COUNT(*), 2) AS over_25_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE f.first_order_amount > 50) / COUNT(*), 2) AS over_50_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE f.first_order_amount > 75) / COUNT(*), 2) AS over_75_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE f.first_order_amount > 100) / COUNT(*), 2) AS over_100_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE f.first_order_amount > 150) / COUNT(*), 2) AS over_150_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE f.first_order_amount > 200) / COUNT(*), 2) AS over_200_pct
FROM customer_repeat_90d r
JOIN customer_first_purchase_90d f
    ON r.customer_unique_id = f.customer_unique_id
WHERE f.first_order_amount IS NOT NULL
GROUP BY r.repeat_purchase_90d
ORDER BY r.repeat_purchase_90d;


-- Compare the percentage of returning vs non-returning customers by number of products in their first order
WITH product_buckets AS (
    SELECT
        r.customer_unique_id,
        r.repeat_purchase_90d,
        CASE
            WHEN f.products_ordered = 1 THEN '1'
            WHEN f.products_ordered = 2 THEN '2'
            WHEN f.products_ordered = 3 THEN '3'
            WHEN f.products_ordered = 4 THEN '4'
            WHEN f.products_ordered >= 5 THEN '5+'
        END AS product_bucket
    FROM customer_repeat_90d r
    JOIN customer_first_purchase_90d f
        ON r.customer_unique_id = f.customer_unique_id
    WHERE f.products_ordered IS NOT NULL
),
bucket_counts AS (
    SELECT
        repeat_purchase_90d,
        product_bucket,
        COUNT(*) AS customers
    FROM product_buckets
    GROUP BY repeat_purchase_90d, product_bucket
),
group_totals AS (
    SELECT
        repeat_purchase_90d,
        COUNT(*) AS total_customers
    FROM product_buckets
    GROUP BY repeat_purchase_90d
)
SELECT
    b.repeat_purchase_90d,
    b.product_bucket,
    b.customers,
    ROUND(100.0 * b.customers / g.total_customers, 2) AS percentage
FROM bucket_counts b
JOIN group_totals g
    ON b.repeat_purchase_90d = g.repeat_purchase_90d
ORDER BY
    b.repeat_purchase_90d,
    CASE b.product_bucket
        WHEN '1' THEN 1
        WHEN '2' THEN 2
        WHEN '3' THEN 3
        WHEN '4' THEN 4
        WHEN '5+' THEN 5
    END;


-- Compare the percentage of returning vs non-returning customers by number of categories in their first order
WITH category_buckets AS (
    SELECT
        r.customer_unique_id,
        r.repeat_purchase_90d,
        CASE
            WHEN f.number_of_categories = 1 THEN '1'
            WHEN f.number_of_categories = 2 THEN '2'
            WHEN f.number_of_categories = 3 THEN '3'
            WHEN f.number_of_categories = 4 THEN '4'
            WHEN f.number_of_categories >= 5 THEN '5+'
        END AS category_bucket
    FROM customer_repeat_90d r
    JOIN customer_first_purchase_90d f
        ON r.customer_unique_id = f.customer_unique_id
    WHERE f.number_of_categories IS NOT NULL
),
bucket_counts AS (
    SELECT
        repeat_purchase_90d,
        category_bucket,
        COUNT(*) AS customers
    FROM category_buckets
    GROUP BY repeat_purchase_90d, category_bucket
),
group_totals AS (
    SELECT
        repeat_purchase_90d,
        COUNT(*) AS total_customers
    FROM category_buckets
    GROUP BY repeat_purchase_90d
)
SELECT
    b.repeat_purchase_90d,
    b.category_bucket,
    b.customers,
    ROUND(100.0 * b.customers / g.total_customers, 2) AS percentage
FROM bucket_counts b
JOIN group_totals g
    ON b.repeat_purchase_90d = g.repeat_purchase_90d
ORDER BY
    b.repeat_purchase_90d,
    CASE b.category_bucket
        WHEN '1' THEN 1
        WHEN '2' THEN 2
        WHEN '3' THEN 3
        WHEN '4' THEN 4
        WHEN '5+' THEN 5
    END;


-- Compare the percentage of returning vs non-returning customers
-- by payment method used on their first order
WITH payment_counts AS (
    SELECT
        r.repeat_purchase_90d,
        f.payment_types,
        COUNT(*) AS customers
    FROM customer_repeat_90d r
    JOIN customer_first_purchase_90d f
        ON r.customer_unique_id = f.customer_unique_id
    WHERE f.payment_types IS NOT NULL
    GROUP BY
        r.repeat_purchase_90d,
        f.payment_types
),
-- Calculate the total number of customers in each group
group_totals AS (
    SELECT
        repeat_purchase_90d,
        SUM(customers) AS total_customers
    FROM payment_counts
    GROUP BY repeat_purchase_90d
)
-- Calculate the percentage for each payment method
SELECT
    p.repeat_purchase_90d,
    p.payment_types,
    p.customers,
    ROUND(
        100.0 * p.customers / g.total_customers,
        2
    ) AS percentage
FROM payment_counts p
JOIN group_totals g
    ON p.repeat_purchase_90d = g.repeat_purchase_90d
ORDER BY
    p.repeat_purchase_90d,
    percentage DESC;


-- Compare the percentage of returning vs non-returning customers by delivery time
WITH delivery_buckets AS (
    SELECT
        r.customer_unique_id,
        r.repeat_purchase_90d,
        CASE
            WHEN f.delivery_days <= 5 THEN '0-5 days'
            WHEN f.delivery_days <= 10 THEN '6-10 days'
            WHEN f.delivery_days <= 15 THEN '11-15 days'
            WHEN f.delivery_days <= 20 THEN '16-20 days'
            WHEN f.delivery_days <= 30 THEN '21-30 days'
            WHEN f.delivery_days > 30 THEN '31+ days'
        END AS delivery_bucket
    FROM customer_repeat_90d r
    JOIN customer_first_purchase_90d f
        ON r.customer_unique_id = f.customer_unique_id
    WHERE f.delivery_days IS NOT NULL
),
bucket_counts AS (
    SELECT
        repeat_purchase_90d,
        delivery_bucket,
        COUNT(*) AS customers
    FROM delivery_buckets
    GROUP BY
        repeat_purchase_90d,
        delivery_bucket
),
group_totals AS (
    SELECT
        repeat_purchase_90d,
        COUNT(*) AS total_customers
    FROM delivery_buckets
    GROUP BY repeat_purchase_90d
)
SELECT
    b.repeat_purchase_90d,
    b.delivery_bucket,
    b.customers,
    ROUND(
        100.0 * b.customers / g.total_customers,
        2
    ) AS percentage
FROM bucket_counts b
JOIN group_totals g
    ON b.repeat_purchase_90d = g.repeat_purchase_90d
ORDER BY
    b.repeat_purchase_90d,
    CASE b.delivery_bucket
        WHEN '0-5 days' THEN 1
        WHEN '6-10 days' THEN 2
        WHEN '11-15 days' THEN 3
        WHEN '16-20 days' THEN 4
        WHEN '21-30 days' THEN 5
        WHEN '31+ days' THEN 6
    END;


-- Compare the percentage of returning vs non-returning customers by freight cost as a percentage of first-order value
WITH freight_buckets AS (
    SELECT
        r.customer_unique_id,
        r.repeat_purchase_90d,
        CASE
            WHEN f.first_order_amount > 0
                AND (f.freight_amount / f.first_order_amount) < 0.10 THEN '<10%'
            WHEN f.first_order_amount > 0
                AND (f.freight_amount / f.first_order_amount) < 0.20 THEN '10-20%'
            WHEN f.first_order_amount > 0
                AND (f.freight_amount / f.first_order_amount) < 0.30 THEN '20-30%'
            WHEN f.first_order_amount > 0
                AND (f.freight_amount / f.first_order_amount) < 0.50 THEN '30-50%'
            WHEN f.first_order_amount > 0
                AND (f.freight_amount / f.first_order_amount) >= 0.50 THEN '50%+'
        END AS freight_percentage_bucket
    FROM customer_repeat_90d r
    JOIN customer_first_purchase_90d f
        ON r.customer_unique_id = f.customer_unique_id
    WHERE f.freight_amount IS NOT NULL
        AND f.first_order_amount IS NOT NULL
        AND f.first_order_amount > 0
),
bucket_counts AS (
    SELECT
        repeat_purchase_90d,
        freight_percentage_bucket,
        COUNT(*) AS customers
    FROM freight_buckets
    WHERE freight_percentage_bucket IS NOT NULL
    GROUP BY
        repeat_purchase_90d,
        freight_percentage_bucket
),
group_totals AS (
    SELECT
        repeat_purchase_90d,
        COUNT(*) AS total_customers
    FROM freight_buckets
    WHERE freight_percentage_bucket IS NOT NULL
    GROUP BY repeat_purchase_90d
)
SELECT
    b.repeat_purchase_90d,
    b.freight_percentage_bucket,
    b.customers,
    ROUND(
        100.0 * b.customers / g.total_customers,
        2
    ) AS percentage
FROM bucket_counts b
JOIN group_totals g
    ON b.repeat_purchase_90d = g.repeat_purchase_90d
ORDER BY
    b.repeat_purchase_90d,
    CASE b.freight_percentage_bucket
        WHEN '<10%' THEN 1
        WHEN '10-20%' THEN 2
        WHEN '20-30%' THEN 3
        WHEN '30-50%' THEN 4
        WHEN '50%+' THEN 5
    END;





